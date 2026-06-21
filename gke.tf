resource "google_service_account" "gke_nodes" {
  account_id   = "gke-nodes"
  display_name = "GKE Node Pool"
  project      = var.project_id
}

resource "google_project_iam_member" "gke_nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_container_cluster" "platform" {
  name     = "platform"
  project  = var.project_id
  location = var.zone

  network    = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.subnet.self_link

  # Disable default node pool — we manage our own
  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "platform-pods"
    services_secondary_range_name = "platform-services"
  }

  # Enforce Kubernetes NetworkPolicies (Calico). Required for tenant network isolation.
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }

    network_policy_config {
      disabled = false
    }
  }

  deletion_protection = false

  depends_on = [
    google_project_service.apis["container.googleapis.com"],
    google_compute_subnetwork.subnet,
  ]
}

resource "google_container_node_pool" "platform" {
  name     = "platform"
  project  = var.project_id
  location = var.zone
  cluster  = google_container_cluster.platform.name

  node_count = 2

  node_config {
    machine_type    = "e2-standard-2"
    disk_type       = "pd-standard"
    disk_size_gb    = 50
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
