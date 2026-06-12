variable "gitops_repo_url" {
  description = "URL of the GitOps repository"
  type        = string
  default     = "https://github.com/inen-pt-group-e/inenp-pt-dmp-platform-gitops"
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "~> 7.0"

  values = [
    yamlencode({
      configs = {
        cm = {
          url             = "https://argocd.mcce-project.xyz"
          "admin.enabled" = "false"
          "dex.config"    = yamlencode({
            connectors = [
              {
                type = "github"
                id   = "github"
                name = "GitHub"
                config = {
                  clientID     = "Ov23liw1ie9WvkVepp72"
                  clientSecret = "$argocd-github-oauth:clientSecret"
                  orgs = [
                    {
                      name  = "inen-pt-group-e"
                      teams = ["platform-admins", "platform-developers", "tenant-viewers"]
                    }
                  ]
                }
              }
            ]
          })
        }
        rbac = {
          "policy.default" = ""
          "policy.csv" = join("\n", [
            "g, inen-pt-group-e:platform-admins, role:admin",
            "p, role:developer, applications, get, */*, allow",
            "p, role:developer, applications, sync, */*, allow",
            "p, role:developer, logs, get, */*, allow",
            "g, inen-pt-group-e:platform-developers, role:developer",
            "p, role:tenant-viewer, applications, get, */*, allow",
            "p, role:tenant-viewer, logs, get, */*, allow",
            "g, inen-pt-group-e:tenant-viewers, role:tenant-viewer",
          ])
        }
        params = {
          "server.insecure" = true
        }
        secret = {
          argocdServerAdminPassword = bcrypt(random_password.generated["argocd_admin_password"].result)
        }
      }
      server = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            memory = "256Mi"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

resource "null_resource" "argocd_app_of_apps" {
  provisioner "local-exec" {
    command     = <<-EOT
      kubectl apply -f - <<EOF
      apiVersion: argoproj.io/v1alpha1
      kind: Application
      metadata:
        name: app-of-apps
        namespace: argocd
      spec:
        project: default
        source:
          repoURL: ${var.gitops_repo_url}
          targetRevision: main
          path: apps
        destination:
          server: https://kubernetes.default.svc
          namespace: argocd
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
      EOF
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [helm_release.argocd]
}
