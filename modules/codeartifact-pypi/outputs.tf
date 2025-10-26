# Domain Outputs
output "domain_name" {
  description = "Name of the CodeArtifact domain"
  value       = aws_codeartifact_domain.domain.domain
}

output "domain_arn" {
  description = "ARN of the CodeArtifact domain"
  value       = aws_codeartifact_domain.domain.arn
}

output "domain_owner" {
  description = "AWS account ID that owns the domain"
  value       = aws_codeartifact_domain.domain.owner
}

# Repository Outputs
output "repository_name" {
  description = "Name of the CodeArtifact repository"
  value       = aws_codeartifact_repository.pypi.repository
}

output "repository_arn" {
  description = "ARN of the CodeArtifact repository"
  value       = aws_codeartifact_repository.pypi.arn
}

output "repository_endpoint" {
  description = "URL endpoint for the repository (use with pip)"
  value       = "https://${aws_codeartifact_domain.domain.domain}-${aws_codeartifact_domain.domain.owner}.d.codeartifact.${data.aws_region.current.id}.amazonaws.com/pypi/${aws_codeartifact_repository.pypi.repository}/simple/"
}

# Configuration Outputs
output "pip_config_instructions" {
  description = "Instructions for configuring pip to use CodeArtifact"
  value = <<-EOT
    # Configure pip to use CodeArtifact (temporary token, expires in 12 hours)

    # 1. Get authentication token and configure pip
    export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token \
      --domain ${aws_codeartifact_domain.domain.domain} \
      --domain-owner ${aws_codeartifact_domain.domain.owner} \
      --query authorizationToken \
      --output text)

    # 2. Configure pip to use CodeArtifact repository
    pip config set global.index-url https://aws:$CODEARTIFACT_AUTH_TOKEN@${aws_codeartifact_domain.domain.domain}-${aws_codeartifact_domain.domain.owner}.d.codeartifact.${data.aws_region.current.id}.amazonaws.com/pypi/${aws_codeartifact_repository.pypi.repository}/simple/

    # Or use --index-url for a single install:
    pip install --index-url https://aws:$CODEARTIFACT_AUTH_TOKEN@${aws_codeartifact_domain.domain.domain}-${aws_codeartifact_domain.domain.owner}.d.codeartifact.${data.aws_region.current.id}.amazonaws.com/pypi/${aws_codeartifact_repository.pypi.repository}/simple/ <package-name>

    # For poetry, add to pyproject.toml:
    [[tool.poetry.source]]
    name = "codeartifact"
    url = "https://aws:$CODEARTIFACT_AUTH_TOKEN@${aws_codeartifact_domain.domain.domain}-${aws_codeartifact_domain.domain.owner}.d.codeartifact.${data.aws_region.current.id}.amazonaws.com/pypi/${aws_codeartifact_repository.pypi.repository}/simple/"
    priority = "primary"
  EOT
}

# Data source to get current AWS region
data "aws_region" "current" {}
