variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "carbon-zone-496411-s6"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west3"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "europe-west3-a"
}

variable "gitops_repo_url" {
  description = "HTTPS URL of the public GitOps repository watched by ArgoCD (App-of-Apps)"
  type        = string
  default     = "https://github.com/inen-pt-group-e/platform-gitops.git"
}

variable "gitops_target_revision" {
  description = "Git branch/revision ArgoCD tracks in the GitOps repository"
  type        = string
  default     = "main"
}

variable "argocd_chart_version" {
  description = "Version of the argo/argo-cd Helm chart to install"
  type        = string
  default     = "7.7.11"
}
