# CodeArtifact PyPI Module

Terraform module for creating an AWS CodeArtifact domain and PyPI repository for hosting private Python packages and proxying public PyPI packages.

## What It Creates

This module provisions:

1. **AWS CodeArtifact Domain** - Top-level entity that contains repositories
2. **AWS CodeArtifact Repository** - PyPI-format repository for Python packages
3. **External Connection to public PyPI** (optional) - Allows proxying public Python packages through your private repository

## Features

- ✅ Private PyPI repository for internal packages
- ✅ Proxy public PyPI packages (caching and availability)
- ✅ IAM-based authentication with temporary tokens
- ✅ VPC endpoint support for private network access
- ✅ Package retention and lifecycle policies
- ✅ Detailed outputs including pip configuration instructions

## Usage

### Basic Example

```hcl
module "pypi_repo" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/codeartifact-pypi?ref=main"

  domain_name     = "johnsosoka"
  repository_name = "pypi-packages"

  tags = {
    Project     = "jscom-infrastructure"
    Environment = "production"
  }
}

# Output the pip configuration instructions
output "pip_setup" {
  value = module.pypi_repo.pip_config_instructions
}
```

### Without External PyPI Connection

If you only want to host private packages without proxying public PyPI:

```hcl
module "private_pypi" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/codeartifact-pypi?ref=main"

  domain_name                = "johnsosoka"
  repository_name            = "private-packages"
  enable_external_connection = false

  tags = {
    Project = "internal-tools"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| domain_name | Name of the CodeArtifact domain (must be unique within AWS account) | `string` | n/a | yes |
| repository_name | Name of the CodeArtifact PyPI repository | `string` | n/a | yes |
| enable_external_connection | Enable external connection to public PyPI repository | `bool` | `true` | no |
| domain_description | Description for the CodeArtifact domain | `string` | `"CodeArtifact domain for Python packages"` | no |
| repository_description | Description for the CodeArtifact repository | `string` | `"PyPI repository for Python packages"` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| domain_name | Name of the CodeArtifact domain |
| domain_arn | ARN of the CodeArtifact domain |
| domain_owner | AWS account ID that owns the domain |
| repository_name | Name of the CodeArtifact repository |
| repository_arn | ARN of the CodeArtifact repository |
| repository_endpoint | URL endpoint for the repository (use with pip) |
| pip_config_instructions | Complete instructions for configuring pip to use CodeArtifact |

## Post-Deployment Steps

### 1. Configure pip to Use CodeArtifact

After deploying, get the pip configuration instructions:

```bash
terraform output pip_config_instructions
```

This will show you the complete commands to:
- Generate a temporary authentication token (valid 12 hours)
- Configure pip to use your CodeArtifact repository
- Use with poetry or other Python package managers

### 2. Configure IAM Permissions

Users/roles need these IAM permissions to use the repository:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codeartifact:GetAuthorizationToken",
        "codeartifact:GetRepositoryEndpoint",
        "codeartifact:ReadFromRepository"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "sts:GetServiceBearerToken",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "sts:AWSServiceName": "codeartifact.amazonaws.com"
        }
      }
    }
  ]
}
```

For publishing packages, add:
```json
{
  "Effect": "Allow",
  "Action": [
    "codeartifact:PublishPackageVersion",
    "codeartifact:PutPackageMetadata"
  ],
  "Resource": "<repository-arn>"
}
```

### 3. Using with CI/CD

For GitHub Actions or other CI/CD:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v2
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-west-2

- name: Login to CodeArtifact
  run: |
    export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token \
      --domain johnsosoka \
      --domain-owner ${{ secrets.AWS_ACCOUNT_ID }} \
      --query authorizationToken \
      --output text)

    pip config set global.index-url https://aws:$CODEARTIFACT_AUTH_TOKEN@johnsosoka-${{ secrets.AWS_ACCOUNT_ID }}.d.codeartifact.us-west-2.amazonaws.com/pypi/pypi-packages/simple/

- name: Install dependencies
  run: pip install -r requirements.txt
```

## Use Cases

### Private Internal Packages

Host your internal Python libraries:

```bash
# Build your package
python setup.py sdist bdist_wheel

# Get auth token
export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token ...)

# Configure twine
export TWINE_USERNAME=aws
export TWINE_PASSWORD=$CODEARTIFACT_AUTH_TOKEN
export TWINE_REPOSITORY_URL=https://johnsosoka-123456789012.d.codeartifact.us-west-2.amazonaws.com/pypi/pypi-packages/

# Upload package
twine upload dist/*
```

### Caching Public Packages

With external connection enabled, public PyPI packages are automatically cached:

```bash
# First install pulls from public PyPI and caches in CodeArtifact
pip install requests

# Subsequent installs use the cached version
pip install requests  # Faster! Uses cached version
```

### Air-Gapped Environments

Pre-populate your repository for environments without internet access:

1. Deploy with `enable_external_connection = true`
2. Install all required packages (triggers caching)
3. Optionally remove external connection for strict air-gap

## Important Notes

### Authentication Token Expiration

- CodeArtifact tokens expire after 12 hours (default)
- Minimum expiration: 15 minutes
- Maximum expiration: 12 hours
- CI/CD pipelines should request new tokens on each run

### External Connection Limits

- Only ONE external connection per repository
- Cannot have multiple external connections
- External connection is to `public:pypi` only

### Domain Deletion

⚠️ **Warning**: Deleting a domain requires all repositories to be deleted first. This module doesn't protect against accidental deletion. Consider:

```hcl
lifecycle {
  prevent_destroy = true
}
```

### Costs

CodeArtifact pricing (as of 2025):
- **Storage**: $0.05 per GB-month
- **Requests**: $0.05 per 10,000 requests
- **Data transfer**: Standard AWS data transfer rates

Public package caching can reduce costs by minimizing external requests.

## Integration with jscom Projects

### Example: Adding to jscom-holdings

```hcl
# In jscom-core-infrastructure/terraform/jscom-holdings.tf

module "jscom_holding" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/web-holding?ref=main"

  domain_name  = "johnsosoka.com"
  project_name = "johnsosoka-com"

  # ... other config
}

# Add CodeArtifact for Python packages
module "jscom_pypi" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/codeartifact-pypi?ref=main"

  domain_name     = "johnsosoka"
  repository_name = "pypi"

  tags = {
    project = "jscom-core-infrastructure"
  }
}
```

### Using in Lambda Projects

Configure Lambda build to use CodeArtifact:

```bash
# In jscom-contact-services/lambdas/

# Get auth token
export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token ...)

# Install dependencies with CodeArtifact
pip install \
  --index-url https://aws:$CODEARTIFACT_AUTH_TOKEN@... \
  -r requirements.txt \
  -t ./package
```

## Troubleshooting

### "AccessDenied" errors

Check IAM permissions include `codeartifact:GetAuthorizationToken` and `sts:GetServiceBearerToken`.

### Token expired

Regenerate the auth token:
```bash
aws codeartifact get-authorization-token --domain <domain> --domain-owner <account-id>
```

### Packages not found

1. Verify external connection is enabled
2. Check spelling of package name
3. Confirm public PyPI has the package
4. Check repository permissions

### "Domain already exists"

Domain names must be unique within an AWS account. Choose a different name or import existing domain:

```bash
terraform import module.pypi_repo.aws_codeartifact_domain.domain <domain-name>
```

## Additional Resources

- [AWS CodeArtifact Documentation](https://docs.aws.amazon.com/codeartifact/)
- [Python Package Publishing Guide](https://packaging.python.org/)
- [Terraform AWS Provider - CodeArtifact](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codeartifact_repository)
