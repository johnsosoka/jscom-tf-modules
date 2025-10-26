# CLAUDE.md

This file provides guidance when working with the jscom-tf-modules repository.

## Repository Overview

This repository houses reusable Terraform modules for the johnsosoka.com (jscom) infrastructure ecosystem. These modules abstract common AWS infrastructure patterns into composable building blocks used across multiple jscom projects.

**Purpose**: Provide standardized, tested Terraform modules that reduce duplication and ensure consistency across all jscom websites and services.

## Related Repositories

This module library is consumed by:
- **jscom-core-infrastructure** - Provides Route53 zones, ACM certificates, and Terraform backend
- **jscom-blog** - johnsosoka.com blog (uses `static-website` module)
- **jscom-contact-services** - Contact form API (uses `base-api` module)
- **kelly-cleaning-www** - Kelly's cleaning site (uses `static-website` module)
- **sosoka-com** - sosoka.com site (uses `web-holding` module)
- **section76-net** - section76.net site (uses `web-holding` module)

**Important**: Changes to modules in this repository affect all consuming projects. Always test changes thoroughly and use semantic versioning via git tags.

## Repository Structure

```
jscom-tf-modules/
├── CLAUDE.md              # This file
├── README.md              # User-facing documentation
├── LICENSE
└── modules/
    ├── base-api/          # API Gateway v2 with custom domain
    ├── lambda-authorizer/ # API key-based Lambda authorizer
    ├── static-website/    # S3 + CloudFront static hosting
    └── web-holding/       # Complete domain infrastructure setup
```

### Module Descriptions

#### base-api
Creates API Gateway v2 (HTTP API) with custom domain, Route53 DNS, and CloudWatch logging. Designed for serverless API backends with Lambda integrations added separately.

**Key Features**:
- API Gateway v2 (HTTP API) with auto-deployment
- Custom domain with automatic DNS configuration
- CloudWatch access logging
- Configurable CORS
- No integrations included (added by consumers)

**Common Usage**: Serverless API backends, webhook receivers, microservices

#### lambda-authorizer
Lambda-based API Gateway v2 REQUEST authorizer for API key validation via HTTP headers.

**Key Features**:
- Zero external dependencies (Python stdlib only)
- Secure environment variable-based key storage
- Configurable header name (default: `x-api-key`)
- Simple boolean responses (API Gateway v2 format)
- Comprehensive CloudWatch logging

**Common Usage**: Admin endpoints, service-to-service authentication, webhook protection

#### static-website
Complete static website hosting infrastructure with S3 origin and CloudFront CDN.

**Key Features**:
- S3 bucket with static website hosting
- CloudFront distribution with HTTPS
- Route53 DNS automation
- ACM certificate integration (must exist in us-east-1)
- OAI (Origin Access Identity) security

**Common Usage**: Jekyll sites, React/Vue SPAs, static documentation sites

#### web-holding
Comprehensive domain infrastructure setup for newly acquired domains. One-stop module for DNS, certificates, and optional email/API configuration.

**Key Features**:
- Route53 hosted zone
- ACM certificates (global us-east-1 for CloudFront, optional regional)
- Email provider setup (Zoho, Gmail, SES)
- Optional SES domain identity with DKIM
- Optional API Gateway instance at api.{domain}
- Wildcard certificate (*.domain.com + domain.com)

**Common Usage**: New domain onboarding, full-stack project foundation

## Module Consumption Patterns

### Git Source References

Modules are consumed via Git source URLs with version pinning:

```hcl
module "my_website" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/static-website?ref=v1.2.0"

  domain_name  = "example.johnsosoka.com"
  root_zone_id = data.terraform_remote_state.core.outputs.root_zone_id
  acm_cert_id  = data.terraform_remote_state.core.outputs.acm_cert_arn
}
```

**Best Practices**:
- Always pin to specific git tags for production (`?ref=v1.2.0`)
- Use `?ref=main` only for development/testing
- Test module changes in isolated environments before tagging

### Terraform Remote State Integration

Modules frequently reference outputs from `jscom-core-infrastructure`:

```hcl
data "terraform_remote_state" "jscom_common_data" {
  backend = "s3"
  config = {
    bucket = "terraform-state-bucket"
    key    = "core-infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}

module "api" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/base-api?ref=main"

  custom_domain_name     = "api.johnsosoka.com"
  domain_certificate_arn = data.terraform_remote_state.jscom_common_data.outputs.jscom_acm_cert
  route53_zone_id        = data.terraform_remote_state.jscom_common_data.outputs.root_johnsosokacom_zone_id
}
```

### Common Module Combinations

**Static Website Stack**:
```hcl
# 1. Core infrastructure (jscom-core-infrastructure repo)
module "core" {
  source = "./core"
  domain_name = "johnsosoka.com"
}

# 2. Static website (consuming project)
module "blog" {
  source       = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/static-website?ref=main"
  domain_name  = "johnsosoka.com"
  root_zone_id = module.core.zone_id
  acm_cert_id  = module.core.global_cert_arn
}
```

**API with Protected Admin Routes**:
```hcl
# 1. Base API Gateway
module "api" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/base-api?ref=main"

  api_gateway_name        = "contact-api"
  custom_domain_name      = "api.johnsosoka.com"
  domain_certificate_arn  = data.terraform_remote_state.core.outputs.jscom_acm_cert
  route53_zone_id         = data.terraform_remote_state.core.outputs.root_zone_id
}

# 2. Lambda authorizer for admin endpoints
module "admin_auth" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/lambda-authorizer?ref=main"

  function_name              = "contact-api-admin-auth"
  api_gateway_id             = module.api.api_gateway_id
  api_gateway_execution_arn  = module.api.api_gateway_execution_arn
  admin_api_key_value        = var.admin_api_key
}

# 3. Protected admin route
resource "aws_apigatewayv2_route" "admin" {
  api_id             = module.api.api_gateway_id
  route_key          = "GET /v1/admin/stats"
  target             = "integrations/${aws_apigatewayv2_integration.admin.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = module.admin_auth.authorizer_id
}
```

**New Domain Quick Start**:
```hcl
module "new_domain" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/web-holding?ref=main"

  domain_name = "newsite.com"

  # Email setup
  email_provider = "gmail"

  # Optional API Gateway
  create_api_gateway = true

  providers = {
    aws.global = aws.us-east-1
  }
}

# Post-apply: Update domain registrar with nameservers from module.new_domain.nameservers
```

## Module Development Best Practices

### Module Structure Standards

Each module follows this structure:

```
module-name/
├── README.md          # Comprehensive usage documentation
├── main.tf            # Primary resource definitions
├── variables.tf       # Input variables with descriptions
├── outputs.tf         # Output values with descriptions
├── {resource}.tf      # Additional resource-specific files
└── lambda_src/        # Lambda source code (if applicable)
```

### Variable Naming Conventions

- Use descriptive, snake_case names: `api_gateway_name`, `domain_certificate_arn`
- Always include `description` and `type`
- Provide `default` values for optional parameters
- Group related variables together in `variables.tf`

**Example**:
```hcl
variable "api_gateway_name" {
  description = "Name of the API Gateway instance"
  type        = string
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
```

### Output Naming Conventions

- Use descriptive names matching AWS resource attributes
- Always include `description`
- Export resource ARNs, IDs, and DNS names for downstream consumption

**Example**:
```hcl
output "api_gateway_id" {
  description = "ID of the API Gateway instance"
  value       = aws_apigatewayv2_api.api.id
}

output "api_gateway_execution_arn" {
  description = "Execution ARN for Lambda permissions"
  value       = aws_apigatewayv2_api.api.execution_arn
}
```

### Tagging Standards

All modules support a `tags` variable for resource tagging:

```hcl
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Apply to resources
resource "aws_apigatewayv2_api" "api" {
  name = var.api_gateway_name

  tags = merge(
    var.tags,
    {
      Module = "base-api"
    }
  )
}
```

**Common jscom tags**:
- `Environment`: `production`, `staging`, `development`
- `Project`: Project identifier (e.g., `jscom-blog`, `contact-services`)
- `ManagedBy`: `terraform`

### Multi-Provider Patterns

Modules requiring resources in multiple AWS regions use provider aliases:

```hcl
# In module code (web-holding/acm.tf)
resource "aws_acm_certificate" "global" {
  provider = aws.global  # us-east-1 for CloudFront

  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
}

# In consuming code
provider "aws" {
  region = "us-west-2"
}

provider "aws" {
  alias  = "global"
  region = "us-east-1"
}

module "domain" {
  source = "./modules/web-holding"

  domain_name = "example.com"

  providers = {
    aws.global = aws.global
  }
}
```

### Lambda Source Code

Modules with Lambda functions include source in `lambda_src/`:

- Keep functions simple with minimal dependencies
- Use Python type hints
- Include comprehensive logging
- Avoid external pip dependencies when possible
- Document handler signature

**Example** (from lambda-authorizer/lambda_src/authorizer.py):
```python
import json
import logging
import os
from typing import Dict, Any

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, bool]:
    """
    API Gateway v2 REQUEST authorizer for API key validation.
    """
    logger.info(f"Authorizer invoked: {json.dumps(event)}")

    admin_api_key = os.environ.get("ADMIN_API_KEY")
    request_api_key = event.get("headers", {}).get("x-api-key")

    is_authorized = request_api_key == admin_api_key

    return {"isAuthorized": is_authorized}
```

## Testing Modules

### Local Testing

Test modules locally before committing:

```bash
cd modules/module-name

# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Plan with test variables
terraform plan -var-file=test.tfvars
```

### Integration Testing

Create test fixtures in consuming projects:

```hcl
# In jscom-contact-services/terraform/test/
module "test_api" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/base-api?ref=feature-branch"

  api_gateway_name        = "test-api"
  custom_domain_name      = "test-api.johnsosoka.com"
  domain_certificate_arn  = data.aws_acm_certificate.test.arn
  route53_zone_id         = data.aws_route53_zone.test.zone_id

  tags = {
    Environment = "test"
  }
}
```

### Testing Checklist

Before merging module changes:

- [ ] `terraform fmt` applied
- [ ] `terraform validate` passes
- [ ] Module documentation updated (README.md)
- [ ] Test deployment in isolated environment
- [ ] Verify outputs are correct
- [ ] Check CloudWatch logs (for Lambda-based modules)
- [ ] Confirm no breaking changes to existing consumers
- [ ] Update version in git tag if needed

## Version Management

### Semantic Versioning

Use semantic versioning for module releases:

- **MAJOR** (v2.0.0): Breaking changes requiring consumer updates
- **MINOR** (v1.1.0): New features, backward compatible
- **PATCH** (v1.0.1): Bug fixes, no new features

### Tagging Releases

```bash
# Create annotated tag
git tag -a v1.2.0 -m "Add support for custom CORS configuration"

# Push tag to remote
git push origin v1.2.0
```

### Version Pinning in Consumers

**Development**:
```hcl
source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/base-api?ref=main"
```

**Production**:
```hcl
source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/base-api?ref=v1.2.0"
```

## Common Workflows

### Adding a New Module

1. Create module directory under `modules/`
2. Implement Terraform code following structure standards
3. Write comprehensive README.md with examples
4. Add module to main README.md
5. Test in isolated environment
6. Create pull request
7. Tag release after merge

### Updating an Existing Module

1. Create feature branch
2. Make changes following standards
3. Update module README.md
4. Test with consuming project
5. Document breaking changes in commit message
6. Create pull request
7. Tag new version after merge

### Deprecating Module Features

When removing features:

1. Mark as deprecated in documentation
2. Add warning to outputs/variables
3. Maintain backward compatibility for one major version
4. Document migration path in README

## AWS Service Patterns

### API Gateway v2 (HTTP API)

Modules use API Gateway v2 HTTP APIs (not REST APIs):

- Simpler, cheaper than REST APIs
- Native HTTP protocol support
- Better integration with Lambda authorizers
- Automatic API deployment via `auto_deploy = true`

### CloudFront + S3 Static Hosting

Static website pattern:

- S3 bucket with website hosting enabled
- CloudFront distribution with S3 origin
- Origin Access Identity (OAI) for security
- ACM certificate in us-east-1 (CloudFront requirement)
- Route53 alias record pointing to CloudFront

### ACM Certificate Validation

Automatic DNS validation:

- Module creates certificate
- Module creates DNS validation records in Route53
- AWS handles validation automatically
- Typically completes in 5-30 minutes

## Troubleshooting

### Module Not Found

**Error**: "Could not download module"

**Solution**: Verify git URL and ref exist:
```bash
git ls-remote https://github.com/johnsosoka/jscom-tf-modules.git
```

### Certificate Validation Timeout

**Error**: Certificate stuck in "Pending Validation"

**Solution**:
- Check Route53 DNS validation records exist
- Verify domain nameservers point to Route53
- Wait up to 30 minutes for DNS propagation

### API Gateway Authorization Fails

**Error**: 401 Unauthorized with lambda-authorizer

**Solution**:
- Check CloudWatch logs: `/aws/lambda/{authorizer-function-name}`
- Verify API key matches exactly (case-sensitive)
- Confirm header name is correct (default: `x-api-key`)
- Check Lambda has correct permissions

## Documentation Standards

Each module must have a comprehensive README.md including:

1. **Purpose**: What the module does
2. **What It Creates**: AWS resources provisioned
3. **Usage Examples**: Basic and advanced usage
4. **Requirements**: Terraform/provider versions
5. **Inputs**: Variable documentation table
6. **Outputs**: Output documentation table
7. **Post-Deployment Steps**: Manual steps required
8. **Notes**: Important considerations
9. **Examples by Use Case**: Real-world scenarios

See `modules/web-holding/README.md` as reference implementation.

## Security Considerations

### Sensitive Variables

Mark sensitive variables appropriately:

```hcl
variable "admin_api_key_value" {
  description = "API key for admin authentication"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_api_key_value) >= 32
    error_message = "API key must be at least 32 characters"
  }
}
```

### IAM Least Privilege

Lambda execution roles follow least privilege:

- Only grant necessary permissions
- Use resource-specific ARNs, not wildcards
- Document required permissions in README

### Secret Management

Prefer AWS Secrets Manager or Parameter Store over environment variables for production secrets:

```hcl
data "aws_secretsmanager_secret_version" "api_key" {
  secret_id = "my-api/admin-key"
}

module "auth" {
  source = "..."
  admin_api_key_value = data.aws_secretsmanager_secret_version.api_key.secret_string
}
```

## Additional Resources

- [Terraform Module Documentation](https://developer.hashicorp.com/terraform/language/modules)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform AWS Lambda Module](https://github.com/terraform-aws-modules/terraform-aws-lambda)
- [API Gateway v2 Best Practices](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html)

## Related Documentation

- [Module Usage Examples](./docs/llm/module-usage-examples.md) - Comprehensive real-world examples
- [Module Development Guide](./docs/llm/module-development-guide.md) - Detailed development workflows

## Questions?

For questions or issues:
1. Check module README.md first
2. Review CloudWatch logs for Lambda-based modules
3. Check consuming project's Terraform state
4. Create GitHub issue with reproduction steps
