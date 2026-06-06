locals {
  github_repo = "inen-pt-group-e/inenp-pt-dmp-platform-iac"
}

# Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "WIF pool for GitHub Actions pipelines"
  project                   = var.project_id

  depends_on = [google_project_service.apis["iam.googleapis.com"]]
}

# OIDC Provider trusting GitHub's token issuer
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"
  project                            = var.project_id

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Only allow tokens from our specific repository
  attribute_condition = "assertion.repository == \"${local.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Dedicated Service Account for the Terraform pipeline
resource "google_service_account" "terraform_pipeline" {
  account_id   = "terraform-pipeline"
  display_name = "Terraform Pipeline"
  project      = var.project_id

  depends_on = [google_project_service.apis["iam.googleapis.com"]]
}

# Roles required to provision the platform
resource "google_project_iam_member" "terraform_pipeline" {
  for_each = toset([
    "roles/container.admin",
    "roles/compute.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/secretmanager.admin",
    "roles/dns.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/iam.serviceAccountUser",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform_pipeline.email}"
}

# Allow the GitHub repo to impersonate the pipeline SA via WIF
resource "google_service_account_iam_member" "terraform_pipeline_wif" {
  service_account_id = google_service_account.terraform_pipeline.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${local.github_repo}"
}
