resource "aws_route53_record" "website_record" {
  zone_id = var.root_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.website_distribution.hosted_zone_id
    // Living dangerously.
    evaluate_target_health = false
  }
}
