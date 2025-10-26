variable "domain_name" {
  description = "Name of the CodeArtifact domain (must be unique within AWS account)"
  type        = string
}

variable "repository_name" {
  description = "Name of the CodeArtifact PyPI repository"
  type        = string
}

variable "enable_external_connection" {
  description = "Enable external connection to public PyPI repository"
  type        = bool
  default     = true
}

variable "domain_description" {
  description = "Description for the CodeArtifact domain"
  type        = string
  default     = "CodeArtifact domain for Python packages"
}

variable "repository_description" {
  description = "Description for the CodeArtifact repository"
  type        = string
  default     = "PyPI repository for Python packages"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
