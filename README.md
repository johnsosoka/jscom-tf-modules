# jscom-tf-modules

Repository to house various jscom terraform modules.


## Modules

### static-website

This module creates a static website hosted on S3 with CloudFront in front of it.

Example Usage:
```hcl
module "static_website" {
  source = "git::https://github.com/johnsosoka/jscom-tf-modulese.git/modules/static-website?ref=main"
  domain_name = "files.johnsosoka.com"
  root_zone_id = data.terraform_remote_state.jscom_common_data.outputs.root_johnsosokacom_zone_id
  acm_cert_id = data.terraform_remote_state.jscom_common_data.outputs.jscom_acm_cert
}
```

