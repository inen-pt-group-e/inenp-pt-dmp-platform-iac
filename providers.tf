provider "google" {
  project = var.project_id
  region  = var.region
}

# Short-lived OAuth token for the current gcloud/CI identity, used to
# authenticate the kubernetes and helm providers against the GKE cluster.
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.platform.endpoint}"
  cluster_ca_certificate = base64decode(google_container_cluster.platform.master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.platform.endpoint}"
    cluster_ca_certificate = base64decode(google_container_cluster.platform.master_auth[0].cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}
