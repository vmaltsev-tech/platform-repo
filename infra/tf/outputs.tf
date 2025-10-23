output "project_id" {
  description = "ID текущего GCP проекта"
  value       = var.project_id
}

output "region" {
  description = "Регион"
  value       = var.region
}

output "cluster_name" {
  description = "Имя GKE-кластера"
  value       = google_container_cluster.gke.name
}

output "network" {
  description = "Имя VPC"
  value       = google_compute_network.vpc.name
}

output "subnet" {
  description = "Имя подсети"
  value       = google_compute_subnetwork.subnet.name
}

output "dns_zone" {
  description = "Имя DNS Managed Zone"
  value       = google_dns_managed_zone.zone.name
}

output "gateway_ip" {
  description = "Статический внешний IP для HTTPS Gateway"
  value       = google_compute_global_address.gateway_ip.address
}

output "domain_name" {
  description = "Доменная зона, управлямая Terraform"
  value       = var.domain_name
}

output "host" {
  description = "Полное доменное имя, обслуживаемое Gateway"
  value       = var.host
}
