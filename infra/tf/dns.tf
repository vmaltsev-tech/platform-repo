resource "google_dns_managed_zone" "zone" {
  name        = "platform-zone"
  dns_name    = "${var.domain_name}."
  description = "Managed zone for ${var.domain_name}"
}

# создаёт A-запись, если указан IP балансера
resource "google_dns_record_set" "app_a" {
  managed_zone = google_dns_managed_zone.zone.name
  name         = "${var.host}."
  type         = "A"
  ttl          = 60
  rrdatas = [
    var.lb_ip != "" ? var.lb_ip : google_compute_global_address.gateway_ip.address,
  ]
}
