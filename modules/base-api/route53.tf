resource "aws_route53_record" "api_gateway_dns" {
  name    = var.custom_domain_name
  type    = "A"
  zone_id = var.route53_zone_id

  alias {
    evaluate_target_health = true
    name                   = module.api_gateway.apigatewayv2_domain_name_target_domain_name
    zone_id                = module.api_gateway.apigatewayv2_domain_name_hosted_zone_id
  }
}