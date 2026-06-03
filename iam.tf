locals {
  service_accounts = {
    eso = {
      account_id   = "eso"
      display_name = "External Secrets Operator"
      roles        = ["roles/secretmanager.secretAccessor"]
    }
    external_dns = {
      account_id   = "external-dns"
      display_name = "ExternalDNS"
      roles        = ["roles/dns.admin"]
    }
    cert_manager = {
      account_id   = "cert-manager"
      display_name = "cert-manager"
      roles        = ["roles/dns.admin"]
    }
    crossplane = {
      account_id   = "crossplane"
      display_name = "Crossplane"
      roles = [
        "roles/editor",
        "roles/iam.serviceAccountAdmin",
        "roles/iam.serviceAccountTokenCreator",
      ]
    }
  }
}

resource "google_service_account" "platform" {
  for_each = local.service_accounts

  account_id   = each.value.account_id
  display_name = each.value.display_name
  project      = var.project_id

  depends_on = [google_project_service.apis["iam.googleapis.com"]]
}

resource "google_project_iam_member" "platform" {
  for_each = {
    for binding in flatten([
      for sa_key, sa in local.service_accounts : [
        for role in sa.roles : {
          key  = "${sa_key}-${role}"
          sa   = sa_key
          role = role
        }
      ]
    ]) : binding.key => binding
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.platform[each.value.sa].email}"
}
