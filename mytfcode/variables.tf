variable "project_name" {
  description = "Prefix for named resources"
  type        = string
  default     = "shopify-mcp"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "shopify_myshopify_domain" {
  description = "Your store's myshopify domain (NOT custom domain), e.g., unfitware.myshopify.com"
  type        = string
  default     = "unfitware.myshopify.com"
}

variable "shopify_api_version" {
  description = "Shopify Admin API version"
  type        = string
  default     = "2025-07"
}

variable "secret_name" {
  description = "Secrets Manager secret name (container only; after Terraform apply, manually add the secret value in AWS Secrets Manager)"
  type        = string
  default     = "shopify/admin"
}

variable "mcp_bearer" {
  description = "Random string used to protect your MCP endpoint (Authorization: Bearer ...)"
  type        = string
  sensitive   = true
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention"
  type        = number
  default     = 14
}

