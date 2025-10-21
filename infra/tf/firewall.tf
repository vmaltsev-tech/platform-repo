resource "google_compute_firewall" "gke_master_to_nodes" {
  name    = "${var.cluster_name}-master-to-nodes"
  network = google_compute_network.vpc.name

  direction = "INGRESS"
  priority  = 1000
  source_ranges = [
    var.master_ipv4_cidr_block,
    "130.211.0.0/22",
    "35.191.0.0/16",
  ]

  target_tags = ["gke-node"]

  allow {
    protocol = "tcp"
    ports    = ["443", "10250"]
  }

  allow {
    protocol = "tcp"
    ports    = ["10255"]
  }
}
