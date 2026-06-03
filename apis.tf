locals {
  gcp_apis = toset([
    "container.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "dns.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
  ])
}

resource "google_project_service" "apis" {
  for_each = local.gcp_apis

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
