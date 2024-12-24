variable "api_gateway_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "api_gateway_description" {
  description = "Description for the API Gateway"
  type        = string
  default     = "API Gateway setup"
}

variable "custom_domain_name" {
  description = "Custom domain name for the API Gateway"
  type        = string
}

variable "domain_certificate_arn" {
  description = "ARN of the ACM certificate for the custom domain"
  type        = string
}

variable "cors_configuration" {
  description = "CORS configuration for the API Gateway"
  type        = map(any)
  default = {
    allow_headers = ["*"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }
}

variable "access_log_format" {
  description = "Format for API Gateway access logs"
  type        = string
  default     = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId $context.integrationErrorMessage"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "route53_zone_id" {
  description = "Route53 Zone ID for the domain"
  type        = string
}