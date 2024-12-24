resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name = "/aws/gateway/${var.api_gateway_name}_logs"

  tags = var.tags
}

module "api_gateway" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "2.2.2"

  name          = var.api_gateway_name
  description   = var.api_gateway_description
  protocol_type = "HTTP"

  cors_configuration = var.cors_configuration

  # Custom domain
  create_api_domain_name      = true
  domain_name                 = var.custom_domain_name
  domain_name_certificate_arn = var.domain_certificate_arn

  # Access logs
  default_stage_access_log_destination_arn = aws_cloudwatch_log_group.api_gateway_log_group.arn
  default_stage_access_log_format          = var.access_log_format

  tags = var.tags
}