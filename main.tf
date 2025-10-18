terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

# Declare modules if they exist


############################
# Secrets Manager (container only — value added later in console)
############################
resource "aws_secretsmanager_secret" "shopify_admin" {
  name        = var.secret_name        # e.g., "shopify/admin"
  description = "Shopify Admin API token for MCP bridge"
}

############################
# IAM for Lambda
############################
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# Allow Lambda to read the specific secret + write logs
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid     = "ReadSecret"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.shopify_admin.arn]
  }

  statement {
    sid     = "Logs"
    effect  = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
  }
}

resource "aws_iam_policy" "lambda_policy" {
  name   = "${var.project_name}-lambda-policy"
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

data "aws_caller_identity" "current" {}

############################
# Package Lambda from local source
############################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-mcp-shopify-admin"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "mcp" {
  function_name = "${var.project_name}-mcp-shopify-admin"
  role          = aws_iam_role.lambda_role.arn
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Node 20 has global fetch built-in
  runtime = "nodejs20.x"
  handler = "index.handler"

  environment {
    variables = {
      SHOPIFY_STORE_DOMAIN = var.shopify_myshopify_domain     # e.g., unfitware.myshopify.com
      SHOPIFY_API_VERSION  = var.shopify_api_version          # e.g., 2025-07
      SECRET_ID            = aws_secretsmanager_secret.shopify_admin.name
      MCP_BEARER           = var.mcp_bearer
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}

############################
# HTTP API Gateway (v2) → Lambda proxy
############################
resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project_name}-httpapi"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.mcp.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "mcp_route" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /mcp"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mcp.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/POST/mcp"
}

