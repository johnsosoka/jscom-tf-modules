variable "domain_name" {
  description = "The domain name for the website"
  type        = string
}

variable "root_zone_id" {
  description = "The zone ID for the root domain"
  type        = string
}

variable "acm_cert_id" {
  description = "The ACM certificate ID for the domain"
  type        = string
}