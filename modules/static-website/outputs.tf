output "website_bucket_id" {
  description = "The ID of the bucket from the static website module"
  value       = aws_s3_bucket.bucket.id
}
