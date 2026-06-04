# Read the ArgoCD admin password generated in Secret Manager (#11). The
# plaintext never appears in code — only in the IAM-protected secret and the
# encrypted Terraform state.
data "google_secret_manager_secret_version" "argocd_admin_password" {
  secret  = "argocd-admin-password"
  project = var.project_id
}

# Derive a STABLE bcrypt hash for the admin password. The htpasswd provider
# persists the salt in state, avoiding the perpetual diff that the built-in
# bcrypt() function would cause on every plan.
resource "htpasswd_password" "argocd_admin" {
  password = data.google_secret_manager_secret_version.argocd_admin_password.secret_data
}

# Day-1 bootstrap: ArgoCD is the only platform component installed by
# Terraform. Everything else (ingress-nginx, cert-manager, ExternalDNS, ESO,
# Crossplane) is reconciled declaratively by the App-of-Apps root Application
# defined in the Helm values (extraObjects).
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  values = [templatefile("${path.module}/argocd-values.yaml.tftpl", {
    admin_password_bcrypt  = htpasswd_password.argocd_admin.bcrypt
    gitops_repo_url        = var.gitops_repo_url
    gitops_target_revision = var.gitops_target_revision
  })]

  depends_on = [google_container_node_pool.platform]
}
