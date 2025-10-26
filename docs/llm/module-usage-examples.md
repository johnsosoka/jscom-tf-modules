# Module Usage Examples

Comprehensive real-world examples for jscom-tf-modules showing common patterns and integration strategies.

## Table of Contents

1. [Static Website Hosting](#static-website-hosting)
2. [Serverless API Backend](#serverless-api-backend)
3. [New Domain Setup](#new-domain-setup)
4. [API with Protected Admin Routes](#api-with-protected-admin-routes)
5. [Multi-Environment Deployments](#multi-environment-deployments)

## Static Website Hosting

### Scenario: Jekyll Blog Deployment

Deploy a Jekyll static site with CloudFront CDN and automatic HTTPS.

**Prerequisites**:
- Route53 hosted zone exists (from jscom-core-infrastructure)
- ACM certificate exists in us-east-1 (from jscom-core-infrastructure)

**Directory Structure**:
```
jscom-blog/
├── website/          # Jekyll site
└── terraform/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

**terraform/main.tf**:
```hcl
terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "jscom-terraform-state"
    key            = "jscom-blog/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "jscom-terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  profile = "jscom"
}

# Reference core infrastructure outputs
data "terraform_remote_state" "core" {
  backend = "s3"
  config = {
    bucket = "jscom-terraform-state"
    key    = "core-infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}

# Production website
module "blog_prod" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/static-website?ref=v1.0.0"

  domain_name  = "johnsosoka.com"
  root_zone_id = data.terraform_remote_state.core.outputs.root_johnsosokacom_zone_id
  acm_cert_id  = data.terraform_remote_state.core.outputs.jscom_acm_cert
}

# Staging website
module "blog_stage" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/static-website?ref=v1.0.0"

  domain_name  = "stage.johnsosoka.com"
  root_zone_id = data.terraform_remote_state.core.outputs.root_johnsosokacom_zone_id
  acm_cert_id  = data.terraform_remote_state.core.outputs.jscom_acm_cert
}
```

**terraform/outputs.tf**:
```hcl
output "prod_s3_bucket" {
  description = "Production S3 bucket for website content"
  value       = module.blog_prod.s3_bucket_id
}

output "prod_cloudfront_id" {
  description = "Production CloudFront distribution ID"
  value       = module.blog_prod.cloudfront_distribution_id
}

output "stage_s3_bucket" {
  description = "Staging S3 bucket for website content"
  value       = module.blog_stage.s3_bucket_id
}

output "stage_cloudfront_id" {
  description = "Staging CloudFront distribution ID"
  value       = module.blog_stage.cloudfront_distribution_id
}
```

**Deployment Workflow**:
```bash
# 1. Build Jekyll site
cd website
bundle exec jekyll build

# 2. Deploy infrastructure (first time)
cd ../terraform
terraform init
terraform plan
terraform apply

# 3. Upload site content
aws s3 sync ../website/_site/ s3://$(terraform output -raw prod_s3_bucket)/ --delete

# 4. Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw prod_cloudfront_id) \
  --paths "/*"
```

## Serverless API Backend

### Scenario: Contact Form API

Build a serverless contact form API with SQS message queuing and DynamoDB storage.

**Architecture**:
- API Gateway v2 HTTP API
- Lambda functions (listener → filter → notifier)
- SQS queues for async processing
- DynamoDB for message storage

**terraform/main.tf**:
```hcl
terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "jscom-terraform-state"
    key            = "contact-services/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "jscom-terraform-locks"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "us-west-2"
  profile = "jscom"
}

# Core infrastructure reference
data "terraform_remote_state" "core" {
  backend = "s3"
  config = {
    bucket = "jscom-terraform-state"
    key    = "core-infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}

# API Gateway
module "contact_api" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/base-api?ref=v1.0.0"

  api_gateway_name        = "jscom-contact-api"
  api_gateway_description = "Contact form submission API"
  custom_domain_name      = "api.johnsosoka.com"
  domain_certificate_arn  = data.terraform_remote_state.core.outputs.jscom_acm_cert_regional
  route53_zone_id         = data.terraform_remote_state.core.outputs.root_johnsosokacom_zone_id

  cors_configuration = {
    allow_headers = ["content-type", "x-api-key"]
    allow_methods = ["POST", "OPTIONS"]
    allow_origins = ["https://johnsosoka.com"]
  }

  tags = {
    Environment = "production"
    Project     = "jscom-contact-services"
  }
}

# SQS Queues
resource "aws_sqs_queue" "contact_message_queue" {
  name                       = "contact-message-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600  # 14 days

  tags = {
    Project = "jscom-contact-services"
  }
}

resource "aws_sqs_queue" "contact_notify_queue" {
  name                       = "contact-notify-queue"
  visibility_timeout_seconds = 60

  tags = {
    Project = "jscom-contact-services"
  }
}

# DynamoDB Tables
resource "aws_dynamodb_table" "all_contact_messages" {
  name         = "all-contact-messages"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "message_id"

  attribute {
    name = "message_id"
    type = "S"
  }

  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }

  tags = {
    Project = "jscom-contact-services"
  }
}

resource "aws_dynamodb_table" "blocked_contacts" {
  name         = "blocked_contacts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"

  attribute {
    name = "email"
    type = "S"
  }

  tags = {
    Project = "jscom-contact-services"
  }
}

# Lambda: Contact Listener
resource "aws_lambda_function" "contact_listener" {
  filename         = "${path.module}/../lambdas/dist/contact-listener.zip"
  function_name    = "contact-listener"
  handler          = "listener.lambda_handler"
  runtime          = "python3.13"
  role             = aws_iam_role.contact_listener_role.arn
  source_code_hash = filebase64sha256("${path.module}/../lambdas/dist/contact-listener.zip")

  environment {
    variables = {
      QUEUE_URL       = aws_sqs_queue.contact_message_queue.url
      DYNAMODB_TABLE  = aws_dynamodb_table.all_contact_messages.name
    }
  }

  tags = {
    Project = "jscom-contact-services"
  }
}

# IAM Role for Contact Listener
resource "aws_iam_role" "contact_listener_role" {
  name = "contact-listener-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "contact_listener_policy" {
  name = "contact-listener-policy"
  role = aws_iam_role.contact_listener_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.contact_message_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.all_contact_messages.arn
      }
    ]
  })
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "contact_listener_integration" {
  api_id             = module.contact_api.api_gateway_id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.contact_listener.invoke_arn
  payload_format_version = "2.0"
}

# API Gateway Route
resource "aws_apigatewayv2_route" "contact_route" {
  api_id    = module.contact_api.api_gateway_id
  route_key = "POST /v1/contact"
  target    = "integrations/${aws_apigatewayv2_integration.contact_listener_integration.id}"
}

# Lambda Permission
resource "aws_lambda_permission" "contact_listener_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_listener.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.contact_api.api_gateway_execution_arn}/*/*"
}
```

**terraform/outputs.tf**:
```hcl
output "api_endpoint" {
  description = "Contact API endpoint"
  value       = "https://${module.contact_api.custom_domain_name}/v1/contact"
}

output "api_gateway_id" {
  value = module.contact_api.api_gateway_id
}
```

## New Domain Setup

### Scenario: Complete Domain Onboarding

Set up a newly acquired domain with DNS, certificates, email, and API infrastructure.

**terraform/main.tf**:
```hcl
terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "jscom-terraform-state"
    key            = "section76-net/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "jscom-terraform-locks"
  }
}

provider "aws" {
  region  = "us-west-2"
  profile = "jscom"
}

provider "aws" {
  alias   = "global"
  region  = "us-east-1"
  profile = "jscom"
}

module "section76_domain" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/web-holding?ref=v1.0.0"

  domain_name  = "section76.net"
  project_name = "section76-net"

  # Certificate configuration
  create_global_cert   = true
  create_regional_cert = false  # Not needed unless using ALB/regional API

  # Email setup (Gmail)
  email_provider = "gmail"

  # Optional: Set up API Gateway at api.section76.net
  create_api_gateway      = true
  api_gateway_name        = "section76-api"
  api_gateway_description = "API services for section76.net"

  # Optional: Enable SES for sending emails
  enable_ses_identity = true

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }

  providers = {
    aws.global = aws.global
  }
}
```

**terraform/outputs.tf**:
```hcl
output "nameservers" {
  description = "Update these nameservers in your domain registrar"
  value       = module.section76_domain.nameservers
}

output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = module.section76_domain.zone_id
}

output "global_cert_arn" {
  description = "ACM certificate ARN for CloudFront (us-east-1)"
  value       = module.section76_domain.global_cert_arn
}

output "global_cert_status" {
  description = "Certificate validation status"
  value       = module.section76_domain.global_cert_status
}

output "api_gateway_id" {
  description = "API Gateway ID (if created)"
  value       = module.section76_domain.api_gateway_id
}

output "api_endpoint" {
  description = "API endpoint URL"
  value       = module.section76_domain.create_api_gateway ? "https://${module.section76_domain.api_custom_domain_name}" : "Not created"
}
```

**Post-Deployment Steps**:
```bash
# 1. Apply Terraform
terraform init
terraform apply

# 2. Get nameservers
terraform output nameservers

# 3. Update domain registrar with nameservers
# (Manual step - log into registrar and update DNS settings)

# 4. Wait for certificate validation (5-30 minutes)
terraform output global_cert_status

# 5. Add static website module for actual content
# (See Static Website Hosting example)
```

## API with Protected Admin Routes

### Scenario: API with Public and Protected Endpoints

Create an API with both public endpoints (contact form) and protected admin endpoints (statistics, user management).

**terraform/main.tf**:
```hcl
terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "jscom-terraform-state"
    key            = "admin-api/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "jscom-terraform-locks"
  }
}

provider "aws" {
  region  = "us-west-2"
  profile = "jscom"
}

# Core infrastructure
data "terraform_remote_state" "core" {
  backend = "s3"
  config = {
    bucket = "jscom-terraform-state"
    key    = "core-infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}

# API Gateway
module "api" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/base-api?ref=v1.0.0"

  api_gateway_name        = "jscom-admin-api"
  api_gateway_description = "API with public and admin endpoints"
  custom_domain_name      = "admin-api.johnsosoka.com"
  domain_certificate_arn  = data.terraform_remote_state.core.outputs.jscom_acm_cert_regional
  route53_zone_id         = data.terraform_remote_state.core.outputs.root_johnsosokacom_zone_id

  cors_configuration = {
    allow_headers = ["content-type", "x-api-key"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_origins = ["https://johnsosoka.com", "https://admin.johnsosoka.com"]
  }

  tags = {
    Environment = "production"
    Project     = "admin-api"
  }
}

# Admin API Key Authorizer
module "admin_authorizer" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/lambda-authorizer?ref=v1.0.0"

  function_name              = "admin-api-authorizer"
  api_gateway_id             = module.api.api_gateway_id
  api_gateway_execution_arn  = module.api.api_gateway_execution_arn
  admin_api_key_value        = var.admin_api_key

  project_name = "admin-api"
  header_name  = "x-admin-key"

  tags = {
    Environment = "production"
  }
}

# Public Lambda (no auth)
resource "aws_lambda_function" "public_endpoint" {
  filename         = "${path.module}/dist/public.zip"
  function_name    = "public-endpoint"
  handler          = "public.handler"
  runtime          = "python3.13"
  role             = aws_iam_role.public_role.arn
  source_code_hash = filebase64sha256("${path.module}/dist/public.zip")

  tags = {
    Project = "admin-api"
  }
}

resource "aws_iam_role" "public_role" {
  name = "public-endpoint-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "public_basic" {
  role       = aws_iam_role.public_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Admin Lambda (protected)
resource "aws_lambda_function" "admin_endpoint" {
  filename         = "${path.module}/dist/admin.zip"
  function_name    = "admin-endpoint"
  handler          = "admin.handler"
  runtime          = "python3.13"
  role             = aws_iam_role.admin_role.arn
  source_code_hash = filebase64sha256("${path.module}/dist/admin.zip")

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.admin_data.name
    }
  }

  tags = {
    Project = "admin-api"
  }
}

resource "aws_iam_role" "admin_role" {
  name = "admin-endpoint-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "admin_basic" {
  role       = aws_iam_role.admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "admin_dynamodb" {
  name = "admin-dynamodb-policy"
  role = aws_iam_role.admin_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]
      Resource = aws_dynamodb_table.admin_data.arn
    }]
  })
}

# DynamoDB Table
resource "aws_dynamodb_table" "admin_data" {
  name         = "admin-data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Project = "admin-api"
  }
}

# Public Route Integration
resource "aws_apigatewayv2_integration" "public_integration" {
  api_id             = module.api.api_gateway_id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.public_endpoint.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "public_route" {
  api_id    = module.api.api_gateway_id
  route_key = "POST /v1/submit"
  target    = "integrations/${aws_apigatewayv2_integration.public_integration.id}"
  # No authorization
}

resource "aws_lambda_permission" "public_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.public_endpoint.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api.api_gateway_execution_arn}/*/*"
}

# Protected Admin Route Integration
resource "aws_apigatewayv2_integration" "admin_integration" {
  api_id             = module.api.api_gateway_id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.admin_endpoint.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "admin_route" {
  api_id    = module.api.api_gateway_id
  route_key = "GET /v1/admin/stats"
  target    = "integrations/${aws_apigatewayv2_integration.admin_integration.id}"

  # Protected with authorizer
  authorization_type = "CUSTOM"
  authorizer_id      = module.admin_authorizer.authorizer_id
}

resource "aws_lambda_permission" "admin_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.admin_endpoint.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api.api_gateway_execution_arn}/*/*"
}
```

**terraform/variables.tf**:
```hcl
variable "admin_api_key" {
  description = "Admin API key for protected endpoints"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_api_key) >= 32
    error_message = "Admin API key must be at least 32 characters"
  }
}
```

**Testing**:
```bash
# Public endpoint (no auth required)
curl -X POST https://admin-api.johnsosoka.com/v1/submit \
  -H "Content-Type: application/json" \
  -d '{"data": "test"}'

# Admin endpoint (requires API key)
curl -X GET https://admin-api.johnsosoka.com/v1/admin/stats \
  -H "x-admin-key: your-secret-admin-key-here"

# Admin endpoint without key (should return 401)
curl -X GET https://admin-api.johnsosoka.com/v1/admin/stats
```

## Multi-Environment Deployments

### Scenario: Production, Staging, Development Environments

Deploy the same infrastructure across multiple environments using Terraform workspaces.

**terraform/main.tf**:
```hcl
terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "jscom-terraform-state"
    key            = "multi-env/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "jscom-terraform-locks"
  }
}

provider "aws" {
  region  = "us-west-2"
  profile = "jscom"
}

locals {
  environment = terraform.workspace

  # Environment-specific configuration
  env_config = {
    production = {
      domain_prefix = ""
      instance_type = "t3.small"
      min_capacity  = 2
    }
    staging = {
      domain_prefix = "stage."
      instance_type = "t3.micro"
      min_capacity  = 1
    }
    development = {
      domain_prefix = "dev."
      instance_type = "t3.micro"
      min_capacity  = 1
    }
  }

  config = local.env_config[local.environment]
}

# Core infrastructure
data "terraform_remote_state" "core" {
  backend = "s3"
  config = {
    bucket = "jscom-terraform-state"
    key    = "core-infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}

# Static Website
module "website" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/static-website?ref=v1.0.0"

  domain_name  = "${local.config.domain_prefix}example.johnsosoka.com"
  root_zone_id = data.terraform_remote_state.core.outputs.root_johnsosokacom_zone_id
  acm_cert_id  = data.terraform_remote_state.core.outputs.jscom_acm_cert
}

# API
module "api" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/base-api?ref=v1.0.0"

  api_gateway_name        = "example-api-${local.environment}"
  api_gateway_description = "API for ${local.environment} environment"
  custom_domain_name      = "${local.config.domain_prefix}api.example.johnsosoka.com"
  domain_certificate_arn  = data.terraform_remote_state.core.outputs.jscom_acm_cert_regional
  route53_zone_id         = data.terraform_remote_state.core.outputs.root_johnsosokacom_zone_id

  tags = {
    Environment = local.environment
    Project     = "example-multi-env"
  }
}
```

**Deployment Workflow**:
```bash
# Initialize Terraform
terraform init

# Create workspaces
terraform workspace new production
terraform workspace new staging
terraform workspace new development

# Deploy to production
terraform workspace select production
terraform plan
terraform apply

# Deploy to staging
terraform workspace select staging
terraform plan
terraform apply

# Deploy to development
terraform workspace select development
terraform plan
terraform apply

# List workspaces
terraform workspace list

# Show current workspace
terraform workspace show
```

## Common Patterns Summary

### Remote State Data Source Pattern
```hcl
data "terraform_remote_state" "core" {
  backend = "s3"
  config = {
    bucket = "jscom-terraform-state"
    key    = "core-infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}

# Use outputs
module.example.root_zone_id = data.terraform_remote_state.core.outputs.root_zone_id
```

### Module Version Pinning Pattern
```hcl
# Development
source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/MODULE?ref=main"

# Production
source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/MODULE?ref=v1.0.0"
```

### Multi-Provider Pattern
```hcl
provider "aws" {
  region = "us-west-2"
}

provider "aws" {
  alias  = "global"
  region = "us-east-1"
}

module "example" {
  source = "..."

  providers = {
    aws.global = aws.global
  }
}
```

### Output Chaining Pattern
```hcl
# Module A
module "api" {
  source = "..."
}

# Module B uses Module A outputs
module "authorizer" {
  source = "..."

  api_gateway_id            = module.api.api_gateway_id
  api_gateway_execution_arn = module.api.api_gateway_execution_arn
}
```
