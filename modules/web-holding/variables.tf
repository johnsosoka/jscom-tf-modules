variable "domain_name" {
  description = "The root domain name (e.g., johnsosoka.com)"
  type        = string
}

variable "create_global_cert" {
  description = "Create ACM certificate in us-east-1 for CloudFront usage"
  type        = bool
  default     = true
}

variable "create_regional_cert" {
  description = "Create ACM certificate in the specified regional region"
  type        = bool
  default     = false
}

variable "regional_cert_region" {
  description = "AWS region for regional certificate (if create_regional_cert is true)"
  type        = string
  default     = "us-west-2"
}

variable "email_provider" {
  description = "Email provider to configure: 'zoho', 'gmail', 'ses', or 'none'"
  type        = string
  default     = "none"
  validation {
    condition     = contains(["zoho", "gmail", "ses", "none"], var.email_provider)
    error_message = "Email provider must be one of: zoho, gmail, ses, none"
  }
}

variable "zoho_verification_code" {
  description = "Zoho mail verification code (zmverify.zoho.com value)"
  type        = string
  default     = ""
}

variable "zoho_domain_key" {
  description = "Zoho DKIM domain key value"
  type        = string
  default     = ""
}

variable "gmail_mx_records" {
  description = "Gmail MX records (if using Gmail)"
  type        = list(string)
  default     = ["1 smtp.google.com"]
}

variable "enable_ses_identity" {
  description = "Enable AWS SES domain identity and DKIM for sending emails"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "web-holding"
}

# API Gateway variables

variable "create_api_gateway" {
  description = "Create API Gateway instance for this domain"
  type        = bool
  default     = false
}

variable "api_gateway_name" {
  description = "Name for the API Gateway (defaults to {project_name}-api)"
  type        = string
  default     = ""
}

variable "api_gateway_description" {
  description = "Description for the API Gateway"
  type        = string
  default     = "API Gateway"
}

variable "api_custom_domain_name" {
  description = "Custom domain for API Gateway (defaults to api.{domain_name})"
  type        = string
  default     = ""
}

variable "cors_configuration" {
  description = "CORS configuration for API Gateway"
  type        = map(any)
  default = {
    allow_headers = ["*"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }
}

variable "api_access_log_format" {
  description = "Format for API Gateway access logs"
  type        = string
  default     = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId $context.integrationErrorMessage"
}
