# Module Development Guide

Detailed workflows and best practices for developing, testing, and maintaining jscom-tf-modules.

## Table of Contents

1. [Development Workflow](#development-workflow)
2. [Module Creation](#module-creation)
3. [Testing Strategies](#testing-strategies)
4. [Documentation Standards](#documentation-standards)
5. [Version Management](#version-management)
6. [CI/CD Integration](#cicd-integration)

## Development Workflow

### Setting Up Development Environment

```bash
# Clone repository
git clone git@github.com:johnsosoka/jscom-tf-modules.git
cd jscom-tf-modules

# Install Terraform
# macOS
brew install terraform

# Verify installation
terraform version

# Configure AWS CLI
aws configure --profile jscom
```

### Branch Strategy

```bash
# Always start from main
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/module-name-enhancement

# Or bug fix branch
git checkout -b bugfix/module-name-issue-description

# Or new module branch
git checkout -b module/new-module-name
```

### Daily Development Loop

1. **Make changes** to module code
2. **Format code**: `terraform fmt -recursive`
3. **Validate syntax**: `terraform validate`
4. **Test locally** with test fixtures
5. **Update documentation**
6. **Commit changes** with descriptive message
7. **Push to remote** and create PR

## Module Creation

### Step-by-Step Module Creation

#### 1. Create Module Directory Structure

```bash
# Create module directory
mkdir -p modules/new-module

# Create standard files
cd modules/new-module
touch main.tf variables.tf outputs.tf README.md
```

#### 2. Define Variables (variables.tf)

```hcl
# Required variables
variable "required_param" {
  description = "Clear description of what this parameter does"
  type        = string

  validation {
    condition     = length(var.required_param) > 0
    error_message = "Required parameter cannot be empty"
  }
}

# Optional variables with defaults
variable "optional_param" {
  description = "Optional parameter with sensible default"
  type        = string
  default     = "default-value"
}

# Complex type variables
variable "config_map" {
  description = "Configuration map for advanced settings"
  type        = map(any)
  default     = {
    setting1 = "value1"
    setting2 = "value2"
  }
}

# Sensitive variables
variable "api_key" {
  description = "API key for authentication"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.api_key) >= 32
    error_message = "API key must be at least 32 characters"
  }
}

# Common tags variable
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Project name for tagging
variable "project_name" {
  description = "Project name for resource identification"
  type        = string
  default     = ""
}
```

#### 3. Implement Resources (main.tf)

```hcl
################################
# Main Resource Definition
################################

resource "aws_example_resource" "main" {
  name        = var.required_param
  description = "Resource created by jscom-tf-modules/new-module"

  # Use variable with validation
  parameter = var.optional_param

  # Apply tags consistently
  tags = merge(
    var.tags,
    {
      Module    = "new-module"
      ManagedBy = "terraform"
    },
    var.project_name != "" ? { Project = var.project_name } : {}
  )
}

################################
# Supporting Resources
################################

resource "aws_supporting_resource" "support" {
  name       = "${var.required_param}-support"
  depends_on = [aws_example_resource.main]

  tags = merge(
    var.tags,
    {
      Module = "new-module"
    }
  )
}

################################
# Data Sources
################################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
```

#### 4. Define Outputs (outputs.tf)

```hcl
################################
# Primary Resource Outputs
################################

output "resource_id" {
  description = "ID of the primary resource"
  value       = aws_example_resource.main.id
}

output "resource_arn" {
  description = "ARN of the primary resource"
  value       = aws_example_resource.main.arn
}

################################
# Supporting Resource Outputs
################################

output "support_resource_id" {
  description = "ID of the supporting resource"
  value       = aws_supporting_resource.support.id
}

################################
# Computed Values
################################

output "resource_url" {
  description = "Public URL of the resource"
  value       = "https://${aws_example_resource.main.domain_name}"
}

################################
# Conditional Outputs
################################

output "optional_output" {
  description = "Output only available when condition is met"
  value       = var.optional_param != "" ? aws_example_resource.main.optional_attribute : null
}
```

#### 5. Write Comprehensive README.md

See [Documentation Standards](#documentation-standards) section below.

### Module with Lambda Function

#### Directory Structure

```
modules/lambda-module/
├── README.md
├── main.tf
├── variables.tf
├── outputs.tf
└── lambda_src/
    ├── handler.py
    ├── requirements.txt  # If needed
    └── tests/
        └── test_handler.py
```

#### Lambda Source Code (lambda_src/handler.py)

```python
"""
Lambda handler for module functionality.

This module provides [description of what it does].
"""

import json
import logging
import os
from typing import Dict, Any, Optional

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler function.

    Args:
        event: Lambda event object
        context: Lambda context object

    Returns:
        Response dictionary with statusCode and body

    Raises:
        ValueError: If required parameters are missing
    """
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        # Extract parameters
        param1 = event.get("param1")
        if not param1:
            raise ValueError("Missing required parameter: param1")

        # Perform logic
        result = process_request(param1)

        # Return success response
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Success",
                "result": result
            })
        }

    except ValueError as e:
        logger.error(f"Validation error: {str(e)}")
        return {
            "statusCode": 400,
            "body": json.dumps({
                "error": str(e)
            })
        }

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": "Internal server error"
            })
        }


def process_request(param: str) -> Dict[str, Any]:
    """
    Process the request with business logic.

    Args:
        param: Input parameter

    Returns:
        Processing result
    """
    # Implementation here
    return {"processed": param}
```

#### Lambda Terraform Integration (main.tf)

```hcl
################################
# Lambda Function Module
################################

module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = var.function_name
  description   = "Lambda function for ${var.project_name}"
  runtime       = var.runtime
  handler       = "handler.lambda_handler"

  # Source path configuration
  source_path = [{
    path             = "${path.module}/lambda_src"
    pip_requirements = fileexists("${path.module}/lambda_src/requirements.txt")
  }]

  # Build configuration
  build_in_docker = var.build_in_docker

  # Environment variables
  environment_variables = merge(
    var.environment_variables,
    {
      LOG_LEVEL = var.log_level
    }
  )

  # Execution configuration
  timeout     = var.timeout
  memory_size = var.memory_size

  # IAM permissions
  attach_policy_statements = true
  policy_statements = {
    dynamodb = {
      effect = "Allow"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem"
      ]
      resources = var.dynamodb_table_arns
    }
  }

  tags = merge(
    var.tags,
    {
      Module = "lambda-module"
    },
    var.project_name != "" ? { Project = var.project_name } : {}
  )
}

################################
# CloudWatch Log Group
################################

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}
```

## Testing Strategies

### Local Testing

#### 1. Syntax Validation

```bash
# Format all files
terraform fmt -recursive

# Validate syntax
cd modules/module-name
terraform validate
```

#### 2. Module Testing with Test Fixtures

Create test fixtures in module directory:

```
modules/module-name/
├── README.md
├── main.tf
├── variables.tf
├── outputs.tf
└── examples/
    ├── basic/
    │   ├── main.tf
    │   └── README.md
    └── advanced/
        ├── main.tf
        └── README.md
```

**Example: modules/static-website/examples/basic/main.tf**

```hcl
terraform {
  required_version = ">= 1.0"
}

provider "aws" {
  region = "us-east-1"
}

# Use local module for testing
module "test_website" {
  source = "../../"  # Points to parent module

  domain_name  = "test.example.com"
  root_zone_id = "Z1234567890ABC"
  acm_cert_id  = "arn:aws:acm:us-east-1:123456789012:certificate/abc123"
}

output "s3_bucket" {
  value = module.test_website.s3_bucket_id
}

output "cloudfront_id" {
  value = module.test_website.cloudfront_distribution_id
}
```

**Testing the example**:

```bash
cd modules/static-website/examples/basic
terraform init
terraform plan
terraform apply -auto-approve

# Verify outputs
terraform output

# Clean up
terraform destroy -auto-approve
```

#### 3. Integration Testing in Consuming Project

Create dedicated test directory in a consuming project:

```
jscom-blog/
└── terraform/
    ├── main.tf              # Production
    └── test/
        └── module-test/
            ├── main.tf      # Test module changes
            └── test.tfvars
```

**terraform/test/module-test/main.tf**:

```hcl
terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket = "jscom-terraform-state"
    key    = "test/module-test/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "jscom"
}

# Test local module changes
module "test_module" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/static-website?ref=feature-branch"

  domain_name  = "test-module.johnsosoka.com"
  root_zone_id = var.root_zone_id
  acm_cert_id  = var.acm_cert_id
}
```

**Testing workflow**:

```bash
cd terraform/test/module-test

# Initialize
terraform init

# Plan
terraform plan -var-file=test.tfvars

# Apply
terraform apply -var-file=test.tfvars

# Verify functionality
# ... manual testing ...

# Clean up
terraform destroy -var-file=test.tfvars
```

### Lambda Function Testing

#### Unit Tests (lambda_src/tests/test_handler.py)

```python
"""
Unit tests for Lambda handler.
"""

import json
import pytest
from unittest.mock import patch, MagicMock
from handler import lambda_handler, process_request


def test_lambda_handler_success():
    """Test successful Lambda invocation."""
    event = {
        "param1": "test-value"
    }
    context = MagicMock()

    response = lambda_handler(event, context)

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["message"] == "Success"
    assert "result" in body


def test_lambda_handler_missing_param():
    """Test Lambda with missing required parameter."""
    event = {}
    context = MagicMock()

    response = lambda_handler(event, context)

    assert response["statusCode"] == 400
    body = json.loads(response["body"])
    assert "error" in body


def test_process_request():
    """Test request processing logic."""
    result = process_request("test-input")

    assert "processed" in result
    assert result["processed"] == "test-input"


@patch("handler.external_service_call")
def test_lambda_handler_with_mock(mock_service):
    """Test Lambda with mocked external dependency."""
    mock_service.return_value = {"data": "mocked"}

    event = {"param1": "test"}
    context = MagicMock()

    response = lambda_handler(event, context)

    assert response["statusCode"] == 200
    mock_service.assert_called_once()
```

**Run tests**:

```bash
cd modules/lambda-module/lambda_src

# Install dependencies
pip install -r requirements.txt
pip install pytest pytest-cov

# Run tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=. --cov-report=html
```

## Documentation Standards

### Module README.md Template

```markdown
# module-name Module

Brief one-sentence description of what this module does.

## Purpose

Detailed explanation of when and why to use this module. Include use cases and scenarios.

## What It Creates

- **Resource 1**: Description of resource and its purpose
- **Resource 2**: Description of resource and its purpose
- **Resource 3**: Description of resource and its purpose

## Features

- Feature 1 with explanation
- Feature 2 with explanation
- Feature 3 with explanation

## Usage

### Basic Example

\`\`\`hcl
module "example" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/module-name?ref=v1.0.0"

  required_param = "value"
}
\`\`\`

### Complete Example with All Options

\`\`\`hcl
provider "aws" {
  region = "us-west-2"
}

module "advanced_example" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/module-name?ref=v1.0.0"

  # Required parameters
  required_param = "value"

  # Optional parameters
  optional_param = "custom-value"

  # Configuration
  config_map = {
    setting1 = "value1"
    setting2 = "value2"
  }

  # Tags
  tags = {
    Environment = "production"
    Project     = "my-project"
  }

  project_name = "my-project"
}
\`\`\`

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 4.0 |

## Providers

This module uses the default AWS provider.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| required_param | Description of required parameter | `string` | n/a | yes |
| optional_param | Description of optional parameter | `string` | `"default"` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| resource_id | ID of the created resource |
| resource_arn | ARN of the created resource |

## Post-Deployment Steps

1. **Step 1**: Description of manual step
2. **Step 2**: Description of manual step

## Notes

- Important consideration 1
- Important consideration 2
- Important consideration 3

## Examples by Use Case

### Use Case 1: Scenario Description

\`\`\`hcl
# Example code
\`\`\`

### Use Case 2: Scenario Description

\`\`\`hcl
# Example code
\`\`\`

## Troubleshooting

### Issue 1

**Error**: Error message

**Solution**: How to resolve

### Issue 2

**Error**: Error message

**Solution**: How to resolve

## Related Modules

- [module-1](../module-1/README.md): Description
- [module-2](../module-2/README.md): Description
```

### Inline Code Documentation

```hcl
################################
# Section Title
################################
#
# Detailed explanation of what this section does.
# Multiple lines are fine for complex logic.

resource "aws_example" "main" {
  # Brief comment explaining non-obvious parameter
  parameter = var.value

  # Explain complex expressions
  computed_value = var.condition ? "value1" : "value2"

  # Document important tags
  tags = merge(
    var.tags,
    {
      Module = "module-name"  # Identifies resources created by this module
    }
  )
}
```

## Version Management

### Semantic Versioning Rules

**MAJOR version (v2.0.0)** - Breaking changes:
- Removed input variables
- Renamed outputs
- Changed resource naming
- Removed resources
- Changed default behavior significantly

**MINOR version (v1.1.0)** - Backward-compatible additions:
- New optional input variables
- New outputs
- New optional resources
- New features that don't break existing usage

**PATCH version (v1.0.1)** - Bug fixes:
- Fixed resource configurations
- Documentation updates
- Bug fixes that don't change behavior

### Tagging Workflow

```bash
# Ensure you're on main with latest changes
git checkout main
git pull origin main

# Create annotated tag
git tag -a v1.2.0 -m "Add support for custom CORS configuration

- Added cors_configuration variable
- Updated API Gateway module to use custom CORS
- Added examples to README"

# Push tag to remote
git push origin v1.2.0

# List all tags
git tag -l

# Show tag details
git show v1.2.0

# Delete tag if needed (use carefully!)
git tag -d v1.2.0              # Delete locally
git push origin --delete v1.2.0 # Delete remotely
```

### Changelog Management

Maintain a CHANGELOG.md in module root:

```markdown
# Changelog

All notable changes to this module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New feature being developed

## [1.2.0] - 2025-10-15

### Added
- Custom CORS configuration support
- New `cors_configuration` variable

### Changed
- Updated API Gateway module to use custom CORS

### Fixed
- Fixed Route53 record creation timing issue

## [1.1.0] - 2025-09-01

### Added
- CloudWatch logging support
- New `log_retention_days` variable

## [1.0.0] - 2025-08-01

### Added
- Initial release
- Basic module functionality
```

## CI/CD Integration

### GitHub Actions Workflow

Create `.github/workflows/terraform-validate.yml`:

```yaml
name: Terraform Validation

on:
  pull_request:
    branches: [main]
    paths:
      - 'modules/**/*.tf'
      - '.github/workflows/terraform-validate.yml'

jobs:
  validate:
    name: Validate Terraform Modules
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0

      - name: Terraform Format Check
        run: |
          terraform fmt -check -recursive

      - name: Validate Modules
        run: |
          for module in modules/*/; do
            echo "Validating $module"
            cd "$module"
            terraform init -backend=false
            terraform validate
            cd ../..
          done

  test:
    name: Test Lambda Functions
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.13'

      - name: Run Lambda Tests
        run: |
          for lambda_dir in modules/*/lambda_src; do
            if [ -d "$lambda_dir" ]; then
              echo "Testing $lambda_dir"
              cd "$lambda_dir"
              pip install -r requirements.txt || true
              pip install pytest pytest-cov
              pytest tests/ -v
              cd ../../..
            fi
          done
```

### Pre-commit Hooks

Create `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
```

Install and use:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

## Best Practices Checklist

Before merging any module changes:

### Code Quality
- [ ] `terraform fmt -recursive` applied
- [ ] `terraform validate` passes
- [ ] No hardcoded values (use variables)
- [ ] All resources tagged appropriately
- [ ] IAM policies follow least privilege

### Documentation
- [ ] README.md updated with examples
- [ ] All variables have descriptions
- [ ] All outputs have descriptions
- [ ] Inline comments for complex logic
- [ ] CHANGELOG.md updated

### Testing
- [ ] Module tested locally with example
- [ ] Lambda functions have unit tests (if applicable)
- [ ] Integration test in consuming project
- [ ] No Terraform state committed

### Version Control
- [ ] Branch named descriptively
- [ ] Commit messages are clear
- [ ] PR description explains changes
- [ ] Breaking changes documented
- [ ] Version tag created (after merge)

## Troubleshooting Development Issues

### Terraform Init Fails

**Issue**: Module not found or download fails

**Solution**:
```bash
# Clear Terraform cache
rm -rf .terraform

# Re-initialize
terraform init -upgrade
```

### State Lock Issues

**Issue**: State lock error during testing

**Solution**:
```bash
# List locks
aws dynamodb scan \
  --table-name jscom-terraform-locks \
  --profile jscom

# Force unlock (use carefully!)
terraform force-unlock LOCK_ID
```

### Module Reference Not Updating

**Issue**: Module changes not reflected in consuming project

**Solution**:
```bash
# Clear module cache
rm -rf .terraform/modules

# Re-initialize with upgrade
terraform init -upgrade

# Or specify module to upgrade
terraform init -upgrade=MODULE_NAME
```

## Questions and Support

For development questions:
1. Check existing module examples
2. Review module documentation
3. Test changes in isolation
4. Create GitHub issue if stuck
