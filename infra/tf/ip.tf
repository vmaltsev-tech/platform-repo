resource "google_compute_global_address" "gateway_ip" {
  name         = "platform-gateway-ip"
  project      = var.project_id
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
  description  = "Static IP for external HTTPS Gateway entrypoint"
}
