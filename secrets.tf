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