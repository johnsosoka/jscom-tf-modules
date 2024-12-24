provider "aws" {
  region = "us-west-2"
}

terraform {
  backend "s3" {
    bucket         = "jscom-tf-backend"
    key            = "project/jscom-tf-test/state/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-state"
  }
}

data "terraform_remote_state" "jscom_common_data" {
  backend = "s3"
  config = {
    bucket = "jscom-tf-backend"
    key    = "project/jscom-core-infra/state/terraform.tfstate"
    region = "us-west-2"
  }
}

locals {
  deployer_user_name = "github-deployer-user"
  root_zone_id       = data.terraform_remote_state.jscom_common_data.outputs.root_johnsosokacom_zone_id
  acm_cert_id        = data.terraform_remote_state.jscom_common_data.outputs.jscom_acm_cert
}

module "api_gateway_test" {
  source                  = "./base-api" # Adjust the path to your module
  api_gateway_name        = "test-api-gateway"
  api_gateway_description = "Test API Gateway module setup"
  custom_domain_name      = "test.johnsosoka.com"
  domain_certificate_arn  = local.acm_cert_id
  route53_zone_id         = local.root_zone_id

  tags = {
    Environment = "test"
    Project     = "api-gateway-module-test"
  }
}