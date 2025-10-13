# Find ARN first (see CLI below), then paste it as the id.
import {
  to = aws_secretsmanager_secret.shopify_admin
  id = "arn:aws:secretsmanager:us-west-2:438465144115:secret:shopify/admin-xlmuwX"
}

# IAM role
import {
  to = aws_iam_role.lambda_role
  id = "shopify-mcp-lambda-role"
}

# CloudWatch log group
import {
  to = aws_cloudwatch_log_group.lambda_logs
  id = "/aws/lambda/shopify-mcp-mcp-shopify-admin"
}
