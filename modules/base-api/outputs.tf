output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = module.api_gateway.apigatewayv2_api_id
}

output "api_gateway_execution_arn" {
  description = "Default endpoint of the API Gateway"
  value       = module.api_gateway.apigatewayv2_api_execution_arn
}

output "custom_domain_name" {
  description = "Custom domain name for the API Gateway"
  value       = var.custom_domain_name
}

output "custom_domain_name_target" {
  description = "Target domain name for the Route53 alias"
  value       = module.api_gateway.apigatewayv2_domain_name_target_domain_name
}

output "custom_domain_hosted_zone_id" {
  description = "Hosted Zone ID for the custom domain"
  value       = module.api_gateway.apigatewayv2_domain_name_hosted_zone_id
}