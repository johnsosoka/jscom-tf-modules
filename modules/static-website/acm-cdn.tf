resource "aws_cloudfront_distribution" "website_distribution" {
  default_root_object = "index.html"

  origin {
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }

    // The URL of our S3 bucket is used as the domain name.
    domain_name = aws_s3_bucket_website_configuration.bucket_website_configuration.website_endpoint
    origin_id   = var.domain_name
  }

  enabled = true

  // The default cache behavior, with standard values from AWS console.
  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = var.domain_name
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  // Ensuring that this distribution is accessible via the provided domain name.
  aliases = [var.domain_name]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  // SSL certificate details.
  viewer_certificate {
    acm_certificate_arn = var.acm_cert_id
    ssl_support_method  = "sni-only"
  }
}
