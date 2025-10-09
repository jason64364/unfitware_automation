output "api_invoke_url" {
  description = "Public MCP endpoint to add in ChatGPT"
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "mcp_full_url" {
  description = "Full POST URL for MCP"
#  value      = "${aws_apigatewayv2_api.http.api_endpoint}/mcp"
   value      = module.mcp.mcp_full_url
}

output "secret_name" {
  description = "Secrets Manager secret name where you must set the Admin token"
#  value      = aws_secretsmanager_secret.shopify_admin.name
   value      = module.mcp.secret_name
}

