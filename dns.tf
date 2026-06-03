resource "google_dns_managed_zone" "platform" {
  name        = "mcce-project-xyz"
  dns_name    = "mcce-project.xyz."
  description = "Platform DNS zone"
  project     = var.project_id
  visibility  = "public"

  depends_on = [google_project_service.apis["dns.googleapis.com"]]
}