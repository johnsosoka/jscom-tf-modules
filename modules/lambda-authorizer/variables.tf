variable "function_name" {
  description = "Name for the Lambda authorizer function"
  type        = string

  validation {
    condition     = length(var.function_name) > 0 && length(var.function_name) <= 64
    error_message = "Function name must be between 1 and 64 characters"
  }
}

variable "api_gateway_id" {
  description = "ID of the API Gateway v2 instance to attach the authorizer to"
  type        = string
}

variable "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway v2 instance (for Lambda permissions)"
  type        = string
}

variable "admin_api_key_value" {
  description = "API key value for authorization. Generate with: openssl rand -hex 32"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_api_key_value) >= 32
    error_message = "API key must be at least 32 characters for security. Generate with: openssl rand -hex 32"
  }
}

variable "project_name" {
  description = "Project name for resource tagging (optional)"
  type        = string
  default     = ""
}

variable "runtime" {
  description = "Python runtime version for the Lambda function"
  type        = string
  default     = "python3.13"

  validation {
    condition     = can(regex("^python3\\.(\\d+)$", var.runtime))
    error_message = "Runtime must be a valid Python 3 runtime (e.g., python3.13, python3.12)"
  }
}

variable "header_name" {
  description = "HTTP header name to validate (e.g., x-api-key)"
  type        = string
  default     = "x-api-key"

  validation {
    condition     = length(var.header_name) > 0
    error_message = "Header name cannot be empty"
  }
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
