output "api_invoke_url" {
  description = "Public MCP endpoint to add in ChatGPT"
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "mcp_full_url" {
  description = "Full POST URL for MCP"
  value       = "${aws_apigatewayv2_api.http.api_endpoint}/mcp"
}

output "secret_name" {
  description = "Secrets Manager secret name"
  value       = aws_secretsmanager_secret.shopify_admin.name
}

