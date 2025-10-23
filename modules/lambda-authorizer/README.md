# lambda-authorizer Module

This module creates a reusable Lambda-based authorizer for API Gateway v2 (HTTP API) that validates API keys via HTTP headers.

## Purpose

Use this module to protect admin or sensitive API endpoints with API key authentication. The authorizer validates a custom header (default: `x-api-key`) against a configured secret value.

## What It Creates

- **Lambda Function**: Python-based authorizer with no external dependencies
- **API Gateway v2 Authorizer**: REQUEST-type authorizer with simple boolean responses
- **Lambda Permission**: Allows API Gateway to invoke the authorizer function

## Features

- **Simple API Key Validation**: Validates requests using a custom HTTP header
- **Zero Dependencies**: Uses only Python standard library
- **Secure**: API key stored as sensitive environment variable
- **Configurable**: Custom header name, runtime version, and function name
- **Logging**: Comprehensive request logging for debugging and auditing
- **Type Safe**: Python code uses type hints for better reliability

## Usage

### Basic Example

```hcl
module "admin_authorizer" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/lambda-authorizer?ref=main"

  function_name              = "my-api-admin-authorizer"
  api_gateway_id             = module.api_gateway.api_gateway_id
  api_gateway_execution_arn  = module.api_gateway.api_gateway_execution_arn
  admin_api_key_value        = var.admin_api_key
}

# Protect an admin route with the authorizer
resource "aws_apigatewayv2_route" "admin_route" {
  api_id    = module.api_gateway.api_gateway_id
  route_key = "ANY /v1/admin/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.admin_integration.id}"

  authorization_type = "CUSTOM"
  authorizer_id      = module.admin_authorizer.authorizer_id
}
```

### Complete Example with All Options

```hcl
module "admin_authorizer" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/lambda-authorizer?ref=main"

  # Required
  function_name              = "contact-admin-authorizer"
  api_gateway_id             = local.api_gateway_id
  api_gateway_execution_arn  = local.execution_arn
  admin_api_key_value        = var.admin_api_key_value

  # Optional customization
  project_name = "jscom-contact-services"
  runtime      = "python3.13"
  header_name  = "x-api-key"

  tags = {
    Environment = "production"
    Service     = "contact-api"
  }
}
```

### Using with jscom base-api Module

```hcl
# Create API Gateway
module "my_api" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/base-api?ref=main"

  api_gateway_name        = "my-api"
  custom_domain_name      = "api.example.com"
  domain_certificate_arn  = data.aws_acm_certificate.cert.arn
  route53_zone_id         = data.aws_route53_zone.main.zone_id
}

# Create authorizer
module "admin_auth" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/lambda-authorizer?ref=main"

  function_name              = "my-api-admin-auth"
  api_gateway_id             = module.my_api.api_gateway_id
  api_gateway_execution_arn  = module.my_api.api_gateway_execution_arn
  admin_api_key_value        = var.admin_api_key
}

# Create protected admin Lambda
resource "aws_lambda_function" "admin" {
  filename      = "admin.zip"
  function_name = "my-api-admin"
  handler       = "admin.handler"
  runtime       = "python3.13"
  role          = aws_iam_role.lambda_role.arn
}

# Integrate admin Lambda with API Gateway
resource "aws_apigatewayv2_integration" "admin" {
  api_id             = module.my_api.api_gateway_id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.admin.invoke_arn
  payload_format_version = "2.0"
}

# Protected route using authorizer
resource "aws_apigatewayv2_route" "admin" {
  api_id    = module.my_api.api_gateway_id
  route_key = "GET /admin/stats"
  target    = "integrations/${aws_apigatewayv2_integration.admin.id}"

  authorization_type = "CUSTOM"
  authorizer_id      = module.admin_auth.authorizer_id
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "admin" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.admin.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.my_api.api_gateway_execution_arn}/*/*"
}
```

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
| function_name | Name for the Lambda authorizer function | `string` | n/a | yes |
| api_gateway_id | ID of the API Gateway v2 instance | `string` | n/a | yes |
| api_gateway_execution_arn | Execution ARN of the API Gateway v2 | `string` | n/a | yes |
| admin_api_key_value | API key value for authorization (min 32 chars) | `string` | n/a | yes |
| project_name | Project name for resource tagging | `string` | `""` | no |
| runtime | Python runtime version | `string` | `"python3.13"` | no |
| header_name | HTTP header name to validate | `string` | `"x-api-key"` | no |
| tags | Additional tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| authorizer_id | ID of the API Gateway v2 authorizer (use when configuring routes) |
| authorizer_name | Name of the API Gateway v2 authorizer |
| lambda_function_name | Name of the Lambda authorizer function |
| lambda_function_arn | ARN of the Lambda authorizer function |
| lambda_function_invoke_arn | Invoke ARN of the Lambda authorizer function |
| lambda_role_arn | ARN of the Lambda execution role |

## How It Works

### Authentication Flow

1. Client makes request to protected API endpoint with API key header
2. API Gateway intercepts request and invokes authorizer Lambda
3. Authorizer extracts header value and compares against environment variable
4. Authorizer returns `{"isAuthorized": true}` or `{"isAuthorized": false}`
5. API Gateway allows/denies request based on response

### Request Format

**Protected API Request:**
```bash
curl -H "x-api-key: your-secret-key-here" \
     https://api.example.com/v1/admin/stats
```

**Authorization Response (from Lambda):**
```json
{
  "isAuthorized": true
}
```

### Security Considerations

1. **API Key Generation**: Use cryptographically secure random generation:
   ```bash
   openssl rand -hex 32
   ```

2. **Secure Storage**: Store API keys in:
   - AWS Secrets Manager (recommended for production)
   - Terraform variables marked as `sensitive = true`
   - Environment-specific `.tfvars` files (gitignored)

3. **Key Rotation**: Plan for periodic key rotation:
   - Update `admin_api_key_value` variable
   - Apply Terraform changes
   - Update clients with new key

4. **Logging**: Authorization attempts are logged to CloudWatch for audit purposes

5. **HTTPS Only**: Always use HTTPS endpoints to prevent key interception

## Advanced Usage

### Custom Header Name

```hcl
module "custom_auth" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/lambda-authorizer?ref=main"

  function_name              = "my-auth"
  api_gateway_id             = module.api.api_gateway_id
  api_gateway_execution_arn  = module.api.api_gateway_execution_arn
  admin_api_key_value        = var.api_key

  header_name = "x-custom-auth-token"  # Use custom header
}
```

### Multiple Authorizers

You can create multiple authorizers for different security contexts:

```hcl
# Admin authorizer
module "admin_auth" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/lambda-authorizer?ref=main"

  function_name              = "my-api-admin-auth"
  api_gateway_id             = module.api.api_gateway_id
  api_gateway_execution_arn  = module.api.api_gateway_execution_arn
  admin_api_key_value        = var.admin_key
}

# Service-to-service authorizer
module "service_auth" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/lambda-authorizer?ref=main"

  function_name              = "my-api-service-auth"
  api_gateway_id             = module.api.api_gateway_id
  api_gateway_execution_arn  = module.api.api_gateway_execution_arn
  admin_api_key_value        = var.service_key
  header_name                = "x-service-key"
}

# Apply different authorizers to different routes
resource "aws_apigatewayv2_route" "admin_route" {
  api_id             = module.api.api_gateway_id
  route_key          = "GET /admin/users"
  target             = "integrations/${aws_apigatewayv2_integration.admin.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = module.admin_auth.authorizer_id
}

resource "aws_apigatewayv2_route" "service_route" {
  api_id             = module.api.api_gateway_id
  route_key          = "POST /internal/sync"
  target             = "integrations/${aws_apigatewayv2_integration.service.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = module.service_auth.authorizer_id
}
```

### Using with AWS Secrets Manager

```hcl
# Store API key in Secrets Manager
resource "aws_secretsmanager_secret" "api_key" {
  name = "my-api/admin-key"
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id     = aws_secretsmanager_secret.api_key.id
  secret_string = var.admin_api_key  # Set this in terraform.tfvars
}

# Retrieve in authorizer module
data "aws_secretsmanager_secret_version" "api_key" {
  secret_id = aws_secretsmanager_secret.api_key.id
}

module "admin_auth" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modules.git//modules/lambda-authorizer?ref=main"

  function_name              = "my-auth"
  api_gateway_id             = module.api.api_gateway_id
  api_gateway_execution_arn  = module.api.api_gateway_execution_arn
  admin_api_key_value        = data.aws_secretsmanager_secret_version.api_key.secret_string
}
```

## Testing the Authorizer

### Valid Request

```bash
curl -i -H "x-api-key: your-secret-key" \
     https://api.example.com/v1/admin/stats

# Expected: HTTP 200 with response from your admin Lambda
```

### Invalid Key

```bash
curl -i -H "x-api-key: wrong-key" \
     https://api.example.com/v1/admin/stats

# Expected: HTTP 401 Unauthorized
```

### Missing Header

```bash
curl -i https://api.example.com/v1/admin/stats

# Expected: HTTP 401 Unauthorized
```

## Troubleshooting

### Authorizer Always Returns 401

1. Check CloudWatch Logs for the authorizer Lambda:
   ```bash
   aws logs tail /aws/lambda/your-authorizer-function-name --follow
   ```

2. Verify API key matches exactly (no extra spaces, correct case)

3. Confirm header name matches configuration (default: `x-api-key`)

### API Gateway Returns 500 Error

1. Check authorizer Lambda has correct permissions
2. Verify Lambda function is not timing out
3. Check Lambda logs for Python errors

### Authorization Works Intermittently

1. Check if API Gateway is caching authorizer responses
2. Verify Lambda has sufficient memory/timeout settings
3. Check for rate limiting or throttling

## Notes

- Authorizer uses API Gateway v2 format with simple boolean responses
- Lambda function has no external dependencies (Python stdlib only)
- Header names are case-insensitive in API Gateway v2 (normalized to lowercase)
- Authorizer responses may be cached by API Gateway based on identity sources
- CloudWatch logs are created automatically at `/aws/lambda/{function_name}`

## Migration from Local Authorizer

If migrating from a local authorizer implementation:

1. Note your current API key value
2. Add this module with same function name
3. Remove local Lambda function resources
4. Update route to use `module.authorizer.authorizer_id`
5. Remove local Lambda source code
6. Test authorization before removing old resources

## Performance

- **Cold Start**: ~100-200ms (no dependencies to load)
- **Warm Execution**: ~1-5ms (simple string comparison)
- **Memory**: 128 MB is sufficient (default Lambda module setting)
- **Timeout**: 3 seconds is sufficient (default Lambda module setting)

## Related Modules

- [base-api](../base-api/README.md): Create API Gateway v2 instance
- [static-website](../static-website/README.md): Host static websites
- [web-holding](../web-holding/README.md): Domain infrastructure setup
