locals {
  workload_identity_bindings = {
    eso = {
      sa_key        = "eso"
      namespace     = "external-secrets"
      kubernetes_sa = "external-secrets"
    }
    external_dns = {
      sa_key        = "external_dns"
      namespace     = "external-dns"
      kubernetes_sa = "external-dns"
    }
    cert_manager = {
      sa_key        = "cert_manager"
      namespace     = "cert-manager"
      kubernetes_sa = "cert-manager"
    }
    crossplane = {
      sa_key        = "crossplane"
      namespace     = "crossplane-system"
      kubernetes_sa = "crossplane"
    }
  }
}

resource "google_service_account_iam_member" "workload_identity" {
  for_each = local.workload_identity_bindings

  service_account_id = google_service_account.platform[each.value.sa_key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.value.kubernetes_sa}]"
}
