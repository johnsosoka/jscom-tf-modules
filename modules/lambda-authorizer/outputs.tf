output "authorizer_id" {
  description = "ID of the API Gateway v2 authorizer (use this when configuring routes)"
  value       = aws_apigatewayv2_authorizer.lambda_authorizer.id
}

output "authorizer_name" {
  description = "Name of the API Gateway v2 authorizer"
  value       = aws_apigatewayv2_authorizer.lambda_authorizer.name
}

output "lambda_function_name" {
  description = "Name of the Lambda authorizer function"
  value       = module.authorizer_lambda.lambda_function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda authorizer function"
  value       = module.authorizer_lambda.lambda_function_arn
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN of the Lambda authorizer function"
  value       = module.authorizer_lambda.lambda_function_invoke_arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.authorizer_lambda.lambda_role_arn
}
