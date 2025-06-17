# Get ALB information for cell1
data "aws_lb" "cell1_alb" {
  name = "${local.cell1_name}-alb"
  depends_on = [kubernetes_manifest.cell1_ingress]
}

# Get ALB information for cell2
data "aws_lb" "cell2_alb" {
  name = "${local.cell2_name}-alb"
  depends_on = [kubernetes_manifest.cell2_ingress]
}

# Get ALB information for cell3
data "aws_lb" "cell3_alb" {
  name = "${local.cell3_name}-alb"
  depends_on = [kubernetes_manifest.cell3_ingress]
}

# Create Route53 records for cell1
resource "aws_route53_record" "cell1_alias" {
  zone_id = var.route53_zone_id
  name    = "cell1.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.aws_lb.cell1_alb.dns_name
    zone_id                = data.aws_lb.cell1_alb.zone_id
    evaluate_target_health = true
  }
  depends_on = [data.aws_lb.cell1_alb]
}

# Create Route53 records for cell2
resource "aws_route53_record" "cell2_alias" {
  zone_id = var.route53_zone_id
  name    = "cell2.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.aws_lb.cell2_alb.dns_name
    zone_id                = data.aws_lb.cell2_alb.zone_id
    evaluate_target_health = true
  }
  depends_on = [data.aws_lb.cell2_alb]
}

# Create Route53 records for cell3
resource "aws_route53_record" "cell3_alias" {
  zone_id = var.route53_zone_id
  name    = "cell3.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.aws_lb.cell3_alb.dns_name
    zone_id                = data.aws_lb.cell3_alb.zone_id
    evaluate_target_health = true
  }
  depends_on = [data.aws_lb.cell3_alb]
}

# Create weighted Route53 record for cell1
resource "aws_route53_record" "main" {
  zone_id        = var.route53_zone_id
  name           = var.domain_name
  type           = "A"
  set_identifier = "cell1"
  
  weighted_routing_policy {
    weight = 33
  }

  alias {
    name                   = data.aws_lb.cell1_alb.dns_name
    zone_id                = data.aws_lb.cell1_alb.zone_id
    evaluate_target_health = true
  }
  depends_on = [data.aws_lb.cell1_alb]
}

# Create weighted Route53 record for cell2
resource "aws_route53_record" "main_cell2" {
  zone_id        = var.route53_zone_id
  name           = var.domain_name
  type           = "A"
  set_identifier = "cell2"
  
  weighted_routing_policy {
    weight = 33
  }

  alias {
    name                   = data.aws_lb.cell2_alb.dns_name
    zone_id                = data.aws_lb.cell2_alb.zone_id
    evaluate_target_health = true
  }
  depends_on = [data.aws_lb.cell2_alb]
}

# Create weighted Route53 record for cell3
resource "aws_route53_record" "main_cell3" {
  zone_id        = var.route53_zone_id
  name           = var.domain_name
  type           = "A"
  set_identifier = "cell3"
  
  weighted_routing_policy {
    weight = 34
  }

  alias {
    name                   = data.aws_lb.cell3_alb.dns_name
    zone_id                = data.aws_lb.cell3_alb.zone_id
    evaluate_target_health = true
  }
  depends_on = [data.aws_lb.cell3_alb]
}

