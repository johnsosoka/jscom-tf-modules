output "zone_id" {
  description = "The Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "zone_name" {
  description = "The Route53 hosted zone name"
  value       = aws_route53_zone.main.name
}

output "nameservers" {
  description = "The nameservers for the hosted zone (set these in your domain registrar)"
  value       = aws_route53_zone.main.name_servers
}

output "global_cert_arn" {
  description = "ARN of the global ACM certificate (us-east-1) for CloudFront"
  value       = var.create_global_cert ? aws_acm_certificate.global[0].arn : null
}

output "global_cert_status" {
  description = "Status of the global certificate validation"
  value       = var.create_global_cert ? aws_acm_certificate.global[0].status : null
}

output "regional_cert_arn" {
  description = "ARN of the regional ACM certificate"
  value       = var.create_regional_cert ? aws_acm_certificate.regional[0].arn : null
}

output "regional_cert_status" {
  description = "Status of the regional certificate validation"
  value       = var.create_regional_cert ? aws_acm_certificate.regional[0].status : null
}

output "ses_identity_arn" {
  description = "ARN of the SES domain identity (if enabled)"
  value       = var.enable_ses_identity ? aws_ses_domain_identity.main[0].arn : null
}

output "ses_verification_token" {
  description = "SES domain verification token (if enabled)"
  value       = var.enable_ses_identity ? aws_ses_domain_identity.main[0].verification_token : null
}

output "email_provider" {
  description = "The configured email provider"
  value       = var.email_provider
}
