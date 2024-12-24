# jscom-tf-modules

Repository to house various jscom terraform modules.


## Modules

### static-website

This module creates a static website hosted on S3 with CloudFront in front of it.

Example Usage:
```hcl
module "static_website" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modulese.git/modules/static-website?ref=main"
  domain_name = "files.johnsosoka.com"
  root_zone_id = data.terraform_remote_state.jscom_common_data.outputs.root_johnsosokacom_zone_id
  acm_cert_id = data.terraform_remote_state.jscom_common_data.outputs.jscom_acm_cert
}
```

### base-api

This module creates a basic API Gateway with no integrations. Integrations are intended to be added in separate modules.

Example Usage:
```hcl

module "api_gateway_test" {
  source                  = "./base-api"
  api_gateway_name        = "test-api-gateway"
  api_gateway_description = "Test API Gateway module setup"
  custom_domain_name      = "test.johnsosoka.com"
  domain_certificate_arn  = local.acm_cert_id
  route53_zone_id         = local.root_zone_id

  tags = {
    Environment = "test"
    Project     = "api-gateway-module-test"
  }
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = module.api_gateway_test.api_gateway_id
}

output "api_gateway_execution_arn" {
  description = "Default endpoint of the API Gateway"
  value       = module.api_gateway_test.api_gateway_execution_arn
}

output "custom_domain_name" {
  description = "Custom domain name for the API Gateway"
  value       = module.api_gateway_test.custom_domain_name
}

output "custom_domain_name_target" {
  description = "Target domain name for the Route53 alias"
  value       = module.api_gateway_test.custom_domain_name_target
}

output "custom_domain_hosted_zone_id" {
  description = "Hosted Zone ID for the custom domain"
  value       = module.api_gateway_test.custom_domain_hosted_zone_id
}
```

#### Example Integration Module

```hcl

resource "aws_lambda_function" "test_function" {
  filename         = "test_function.zip"
  function_name    = "test-function"
  handler          = "test.handler"
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("test_function.zip")

  role = aws_iam_role.lambda_execution_role.arn
}

resource "aws_iam_role" "lambda_execution_role" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_apigatewayv2_integration" "test_integration" {
  api_id             = data.terraform_remote_state.api_gateway.outputs.api_gateway_id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.test_function.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "test_route" {
  api_id    = data.terraform_remote_state.api_gateway.outputs.api_gateway_id
  route_key = "POST /test"
  target    = "integrations/${aws_apigatewayv2_integration.test_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_function.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${data.terraform_remote_state.api_gateway.outputs.api_gateway_execution_arn}/*/*"
}

output "test_route_endpoint" {
  value = "${data.terraform_remote_state.api_gateway.outputs.custom_domain_name}/test"
}
```

**Test Lambda**
    
```javascript
// test.js
exports.handler = async (event) => {
    console.log("Event: ", event);
    return {
        statusCode: 200,
        body: JSON.stringify({ message: "Hello from test!" }),
    };
};
```