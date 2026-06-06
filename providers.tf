provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_container_cluster" "platform" {
  name     = "platform"
  location = var.zone
  project  = var.project_id
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.platform.endpoint}"
    cluster_ca_certificate = base64decode(data.google_container_cluster.platform.master_auth[0].cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.platform.endpoint}"
  cluster_ca_certificate = base64decode(data.google_container_cluster.platform.master_auth[0].cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
}
