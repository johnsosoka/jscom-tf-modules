# Global Certificate (us-east-1) for CloudFront
resource "aws_acm_certificate" "global" {
  count    = var.create_global_cert ? 1 : 0
  provider = aws.global

  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.domain_name}-global"
      Project = var.project_name
    }
  )
}

# DNS validation records for global certificate
resource "aws_route53_record" "global_cert_validation" {
  for_each = var.create_global_cert ? {
    for dvo in aws_acm_certificate.global[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  provider = aws.global

  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  zone_id         = aws_route53_zone.main.zone_id
  ttl             = 60
}

# Certificate validation for global cert
resource "aws_acm_certificate_validation" "global" {
  count    = var.create_global_cert ? 1 : 0
  provider = aws.global

  certificate_arn         = aws_acm_certificate.global[0].arn
  validation_record_fqdns = [for record in aws_route53_record.global_cert_validation : record.fqdn]
}

# Regional Certificate (for regional services like ALB, API Gateway)
resource "aws_acm_certificate" "regional" {
  count = local.should_create_regional_cert ? 1 : 0

  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.domain_name}-regional"
      Project = var.project_name
    }
  )
}

# DNS validation records for regional certificate
resource "aws_route53_record" "regional_cert_validation" {
  for_each = local.should_create_regional_cert ? {
    for dvo in aws_acm_certificate.regional[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  zone_id         = aws_route53_zone.main.zone_id
  ttl             = 60
}

# Certificate validation for regional cert
resource "aws_acm_certificate_validation" "regional" {
  count = local.should_create_regional_cert ? 1 : 0

  certificate_arn         = aws_acm_certificate.regional[0].arn
  validation_record_fqdns = [for record in aws_route53_record.regional_cert_validation : record.fqdn]
}
