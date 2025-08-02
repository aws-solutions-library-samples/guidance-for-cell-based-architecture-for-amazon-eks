variable "domain_name" {
  description = "Domain name for the Route53 zone"
  type        = string
  default     = "anycompany.com"
}

variable "route53_zone_id" {
  description = "ID of the existing Route53 hosted zone"
  type        = string
  default     = "YOUR_ROUTE53_ZONE_ID"
}

variable "acm_certificate_arn" {
  description = "ARN of the existing ACM certificate"
  type        = string
  default     = "YOUR_ACM_CERTIFICATE_ARN"
}

variable "region" {
  description = "AWS region for deployment"
  type        = string
}

