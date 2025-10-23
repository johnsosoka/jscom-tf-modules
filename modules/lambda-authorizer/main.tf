################################
# Lambda Authorizer Function
################################

module "authorizer_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = var.function_name
  description   = "Lambda authorizer for API Gateway v2 API key validation"
  runtime       = var.runtime
  handler       = "authorizer.lambda_handler"

  # No Docker build needed - no external dependencies
  build_in_docker = false

  source_path = [{
    path             = "${path.module}/lambda_src"
    pip_requirements = false
  }]

  environment_variables = {
    ADMIN_API_KEY = var.admin_api_key_value
  }

  tags = merge(
    var.tags,
    var.project_name != "" ? { project = var.project_name } : {}
  )
}

################################
# API Gateway v2 Authorizer
################################

resource "aws_apigatewayv2_authorizer" "lambda_authorizer" {
  api_id          = var.api_gateway_id
  authorizer_type = "REQUEST"
  name            = "${var.function_name}-authorizer"
  authorizer_uri  = module.authorizer_lambda.lambda_function_invoke_arn

  # API Gateway v2 format with simple boolean responses
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true

  # Identity source - header to extract for validation
  identity_sources = ["$request.header.${var.header_name}"]
}

################################
# Lambda Permission
################################

resource "aws_lambda_permission" "authorizer_permission" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = module.authorizer_lambda.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/authorizers/${aws_apigatewayv2_authorizer.lambda_authorizer.id}"
}
