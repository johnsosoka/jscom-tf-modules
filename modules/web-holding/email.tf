###################
# Zoho Mail Setup #
###################

resource "aws_route53_record" "zoho_mx" {
  count = var.email_provider == "zoho" ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = ""
  type    = "MX"
  ttl     = 300
  records = [
    "10 mx.zoho.com",
    "20 mx2.zoho.com",
    "50 mx3.zoho.com"
  ]
}

resource "aws_route53_record" "zoho_spf" {
  count = var.email_provider == "zoho" ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = ""
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:zoho.com ~all"]
}

resource "aws_route53_record" "zoho_dkim" {
  count = var.email_provider == "zoho" && var.zoho_domain_key != "" ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = "zmail._domainkey"
  type    = "TXT"
  ttl     = 300
  records = [var.zoho_domain_key]
}

resource "aws_route53_record" "zoho_verification" {
  count = var.email_provider == "zoho" && var.zoho_verification_code != "" ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = ""
  type    = "TXT"
  ttl     = 300
  records = [var.zoho_verification_code]
}

###################
# Gmail Setup     #
###################

resource "aws_route53_record" "gmail_mx" {
  count = var.email_provider == "gmail" ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = ""
  type    = "MX"
  ttl     = 300
  records = var.gmail_mx_records
}

###################
# AWS SES Setup   #
###################

resource "aws_ses_domain_identity" "main" {
  count = var.enable_ses_identity ? 1 : 0

  domain = var.domain_name
}

resource "aws_ses_domain_dkim" "main" {
  count = var.enable_ses_identity ? 1 : 0

  domain = aws_ses_domain_identity.main[0].domain
}

resource "aws_route53_record" "ses_dkim" {
  count = var.enable_ses_identity ? 3 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = "${aws_ses_domain_dkim.main[0].dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.main[0].dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# SES MX record (if using SES as primary email)
resource "aws_route53_record" "ses_mx" {
  count = var.email_provider == "ses" ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = ""
  type    = "MX"
  ttl     = 300
  records = ["10 inbound-smtp.us-west-2.amazonaws.com"]
}

# SES SPF record
resource "aws_route53_record" "ses_spf" {
  count = var.email_provider == "ses" ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = ""
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com ~all"]
}
