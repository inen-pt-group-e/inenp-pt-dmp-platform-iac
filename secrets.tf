locals {
  generated_secrets = {
    argocd_admin_password = {
      secret_id = "argocd-admin-password"
    }
    db_password = {
      secret_id = "db-password"
    }
  }
}

resource "random_password" "generated" {
  for_each = local.generated_secrets

  length  = 32
  special = true
}

resource "google_secret_manager_secret" "generated" {
  for_each = local.generated_secrets

  project   = var.project_id
  secret_id = each.value.secret_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_version" "generated" {
  for_each = local.generated_secrets

  secret      = google_secret_manager_secret.generated[each.key].id
  secret_data = random_password.generated[each.key].result
}
# ArgoCD GitHub SSO OAuth client secret.
# Value comes from GitHub and is uploaded manually (cannot be auto-generated);
# Terraform manages only the container + write access. ESO syncs it into the cluster.
resource "google_secret_manager_secret" "argocd_github_oauth" {
  project   = var.project_id
  secret_id = "argocd-github-oauth-client-secret"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_iam_member" "argocd_github_oauth_writers" {
  for_each = toset(var.argocd_oauth_secret_writers)

  project   = var.project_id
  secret_id = google_secret_manager_secret.argocd_github_oauth.secret_id
  role      = "roles/secretmanager.secretVersionAdder"
  member    = each.value
}
