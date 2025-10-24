terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
      configuration_aliases = [aws.global]
    }
  }
}

# Local variables
locals {
  # Auto-enable regional cert if API Gateway is requested
  should_create_regional_cert = var.create_regional_cert || var.create_api_gateway
}

# Route53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = merge(
    var.tags,
    {
      Name    = var.domain_name
      Project = var.project_name
    }
  )
}
