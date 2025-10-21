resource "google_container_cluster" "gke" {
  name     = var.cluster_name
  location = var.zone

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  # Dataplane v2 (Advanced Datapath)
  networking_mode   = "VPC_NATIVE"
  datapath_provider = "ADVANCED_DATAPATH"

  # Приватные ноды, публичный API (можно работать с твоего IP)
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # ← оставляем публичный endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  # Доступ к API только с твоего IP
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "58.29.72.148/32"
      display_name = "home-ip"
    }
  }

  vertical_pod_autoscaling {
    enabled = true
  }

  enable_shielded_nodes = true
  deletion_protection   = false
  description           = "GKE private cluster (private nodes, public API) доступен только с IP 58.29.72.148"
}

resource "google_container_node_pool" "default" {
  name     = "np-e2s4"
  location = var.zone
  cluster  = google_container_cluster.gke.name

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    machine_type = "e2-standard-4"

    # Меняем тип диска, чтобы не упереться в SSD квоту
    disk_type       = "pd-balanced" # ← HDD, не тратит SSD_TOTAL_GB квоту
    disk_size_gb    = 50            # ← уменьшен для экономии квоты
    service_account = google_service_account.gke_nodes.email

    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = { env = "platform" }

    metadata = { disable-legacy-endpoints = "true" }

    tags = ["gke-node"]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}
