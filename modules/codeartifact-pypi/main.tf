resource "aws_codeartifact_domain" "domain" {
  domain = var.domain_name

  tags = merge(
    var.tags,
    {
      Name        = var.domain_name
      Description = var.domain_description
      Module      = "codeartifact-pypi"
    }
  )
}
