output "website_bucket_id" {
  description = "The ID of the bucket from the static website module"
  value       = aws_s3_bucket.bucket.id
}

output "cloudfront_distribution_id" {
  description = "The ID of the related CloudFront distribution in-front of S3"
  value = aws_cloudfront_distribution.website_distribution.id
}
