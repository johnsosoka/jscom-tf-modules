# Optional API Gateway Integration
# Creates an API Gateway instance at api.{domain_name} when enabled

module "api" {
  count  = var.create_api_gateway ? 1 : 0
  source = "../base-api"

  api_gateway_name        = var.api_gateway_name != "" ? var.api_gateway_name : "${var.project_name}-api"
  api_gateway_description = var.api_gateway_description
  custom_domain_name      = var.api_custom_domain_name != "" ? var.api_custom_domain_name : "api.${var.domain_name}"
  domain_certificate_arn  = local.should_create_regional_cert ? aws_acm_certificate.regional[0].arn : null
  route53_zone_id         = aws_route53_zone.main.zone_id
  cors_configuration      = var.cors_configuration
  access_log_format       = var.api_access_log_format
  tags                    = var.tags
}
