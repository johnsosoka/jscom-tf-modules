resource "aws_codeartifact_repository" "pypi" {
  repository = var.repository_name
  domain     = aws_codeartifact_domain.domain.domain
  description = var.repository_description

  dynamic "external_connections" {
    for_each = var.enable_external_connection ? [1] : []
    content {
      external_connection_name = "public:pypi"
    }
  }

  tags = merge(
    var.tags,
    {
      Name   = var.repository_name
      Module = "codeartifact-pypi"
    }
  )
}
