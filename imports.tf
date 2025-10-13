# Find ARN first (see CLI below), then paste it as the id.
import {
  to = aws_secretsmanager_secret.shopify_admin
  id = "arn:aws:secretsmanager:us-west-2:438465144115:secret:shopify/admin-xlmuwX"
}

# 2) IAM role
import {
  to = aws_iam_role.lambda_role
  id = "arn:aws:iam::438465144115:role/shopify-mcp-lambda-role"
}

# 3) CloudWatch log group
import {
  to = aws_cloudwatch_log_group.lambda_logs
  id = "arn:aws:logs:us-west-2:438465144115:log-group:/aws/lambda/shopify-mcp-mcp-shopify-admin:*"
}
