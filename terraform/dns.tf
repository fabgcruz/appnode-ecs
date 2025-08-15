# DNS Configuration for custom domain
data "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0
  name  = regex("([^.]+\\.[^.]+)$", var.domain_name)[0]
}

resource "aws_route53_record" "app" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = false
  }
}

# Output DNS information
output "domain_name" {
  description = "Custom domain name (if configured)"
  value       = var.domain_name != "" ? var.domain_name : "Not configured"
}

output "dns_record_fqdn" {
  description = "Full DNS record created"
  value       = var.domain_name != "" ? aws_route53_record.app[0].fqdn : "Not configured"
}