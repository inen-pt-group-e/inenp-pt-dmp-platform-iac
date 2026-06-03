resource "google_secret_manager_secret" "ghcr_token" {
  secret_id = "ghcr-token"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}