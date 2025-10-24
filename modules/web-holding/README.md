# web-holding Module

This module establishes foundational AWS infrastructure for a domain, including Route53 hosted zone, ACM certificates, and email provider configuration.

## Purpose

Use this module when you acquire a new domain and want to set up the core AWS infrastructure needed before deploying websites or services.

## What It Creates

- **Route53 Hosted Zone**: DNS authority for your domain
- **ACM Certificates**:
  - Global certificate (us-east-1) for CloudFront
  - Optional regional certificate for services like ALB, API Gateway (auto-enabled if API Gateway is created)
- **Email Configuration**: Support for Zoho, Gmail, or AWS SES
- **SES Identity**: Optional AWS SES domain identity and DKIM for sending emails
- **API Gateway**: Optional API Gateway instance at api.{domain_name}

## Usage

### Basic Example

```hcl
module "my_domain" {
  source = "./modules/web-holding"

  domain_name = "example.com"
}
```

### Complete Example with Zoho Email

```hcl
provider "aws" {
  region = "us-west-2"
}

provider "aws" {
  alias  = "global"
  region = "us-east-1"
}

module "johnsosoka_holding" {
  source = "./modules/web-holding"

  # Required
  domain_name = "johnsosoka.com"

  # Certificate configuration
  create_global_cert   = true   # For CloudFront (us-east-1)
  create_regional_cert = true   # For regional services (us-west-2)

  # Email provider
  email_provider         = "zoho"
  zoho_domain_key        = "v=DKIM1; k=rsa; p=..."
  zoho_verification_code = "zmverify.zoho.com"

  # SES for sending emails
  enable_ses_identity = true

  # Tags
  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }

  project_name = "personal-portfolio"

  # Provider configuration
  providers = {
    aws.global = aws.global
  }
}
```

### Gmail Email Configuration

```hcl
module "my_domain" {
  source = "./modules/web-holding"

  domain_name    = "example.com"
  email_provider = "gmail"

  providers = {
    aws.global = aws.global
  }
}
```

### SES as Primary Email

```hcl
module "my_domain" {
  source = "./modules/web-holding"

  domain_name         = "example.com"
  email_provider      = "ses"
  enable_ses_identity = true

  providers = {
    aws.global = aws.global
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 4.0 |

## Providers

This module requires two AWS provider configurations:
- Default provider (for regional resources)
- `aws.global` aliased provider (for us-east-1 resources like CloudFront certificates)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| domain_name | The root domain name | `string` | n/a | yes |
| create_global_cert | Create ACM cert in us-east-1 for CloudFront | `bool` | `true` | no |
| create_regional_cert | Create ACM cert in regional region | `bool` | `false` | no |
| regional_cert_region | AWS region for regional certificate | `string` | `"us-west-2"` | no |
| email_provider | Email provider: zoho, gmail, ses, or none | `string` | `"none"` | no |
| zoho_verification_code | Zoho mail verification code | `string` | `""` | no |
| zoho_domain_key | Zoho DKIM domain key value | `string` | `""` | no |
| gmail_mx_records | Gmail MX records | `list(string)` | `["1 smtp.google.com"]` | no |
| enable_ses_identity | Enable AWS SES domain identity | `bool` | `false` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |
| project_name | Project name for tagging | `string` | `"web-holding"` | no |
| create_api_gateway | Create API Gateway instance | `bool` | `false` | no |
| api_gateway_name | Name for API Gateway | `string` | `"{project_name}-api"` | no |
| api_gateway_description | Description for API Gateway | `string` | `"API Gateway"` | no |
| api_custom_domain_name | Custom domain for API Gateway | `string` | `"api.{domain_name}"` | no |
| cors_configuration | CORS configuration for API Gateway | `map(any)` | `{allow_headers=["*"], allow_methods=["*"], allow_origins=["*"]}` | no |
| api_access_log_format | Format for API Gateway access logs | `string` | Standard format | no |

## Outputs

| Name | Description |
|------|-------------|
| zone_id | Route53 hosted zone ID |
| zone_name | Route53 hosted zone name |
| nameservers | Nameservers (set these in domain registrar) |
| global_cert_arn | ARN of global certificate (us-east-1) |
| global_cert_status | Status of global certificate validation |
| regional_cert_arn | ARN of regional certificate |
| regional_cert_status | Status of regional certificate validation |
| ses_identity_arn | ARN of SES domain identity |
| ses_verification_token | SES domain verification token |
| email_provider | Configured email provider |
| api_gateway_id | ID of the API Gateway (if created) |
| api_gateway_execution_arn | Execution ARN of the API Gateway (if created) |
| api_custom_domain_name | Custom domain name for API Gateway (if created) |
| api_custom_domain_target | Target domain for API Gateway (if created) |
| api_custom_domain_hosted_zone_id | Hosted zone ID for API Gateway custom domain (if created) |

## Post-Deployment Steps

1. **Update Domain Registrar**: Copy the nameservers from the `nameservers` output and configure them in your domain registrar
2. **Certificate Validation**: Certificates validate automatically via DNS, but can take 5-30 minutes
3. **Email Configuration**: Follow your email provider's instructions to complete setup (may require additional verification)

## Notes

- The module creates wildcard certificates that include the root domain (e.g., `*.example.com` + `example.com`)
- Certificate validation is automatic via DNS records created in the hosted zone
- Regional certificate is optional and only needed if you use services like ALB or API Gateway in a specific region
  - **Note**: Regional certificate is automatically enabled when `create_api_gateway = true`
- Email provider configuration is optional - use `email_provider = "none"` if managing email elsewhere
- API Gateway, when enabled, is created at `api.{domain_name}` by default (customizable via `api_custom_domain_name`)

## Examples by Use Case

### New Domain - Just DNS and Certs
```hcl
module "new_domain" {
  source = "./modules/web-holding"
  domain_name = "newdomain.com"

  providers = {
    aws.global = aws.global
  }
}
```

### Domain for CloudFront Sites with Email
```hcl
module "portfolio_site" {
  source = "./modules/web-holding"

  domain_name          = "portfolio.com"
  create_global_cert   = true
  create_regional_cert = false

  email_provider = "gmail"

  providers = {
    aws.global = aws.global
  }
}
```

### Full Stack Domain (CloudFront + ALB + Email)
```hcl
module "full_domain" {
  source = "./modules/web-holding"

  domain_name          = "fullstack.com"
  create_global_cert   = true
  create_regional_cert = true

  email_provider      = "zoho"
  zoho_domain_key     = var.zoho_dkim
  enable_ses_identity = true

  providers = {
    aws.global = aws.global
  }
}
```

### Domain with API Gateway
```hcl
module "api_domain" {
  source = "./modules/web-holding"

  domain_name  = "example.com"
  project_name = "example-com"

  # API Gateway configuration
  create_api_gateway       = true
  api_gateway_name         = "example-api"
  api_gateway_description  = "API services for example.com"

  # Optional: customize API domain (defaults to api.example.com)
  # api_custom_domain_name = "api.example.com"

  # Email configuration
  email_provider = "gmail"

  providers = {
    aws.global = aws.global
  }
}

# Use the API Gateway outputs
output "api_gateway_id" {
  value = module.api_domain.api_gateway_id
}

output "api_gateway_execution_arn" {
  value = module.api_domain.api_gateway_execution_arn
}
```
