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

variable "argocd_oauth_secret_writers" {
  description = "Principals (user:/group:) allowed to add the ArgoCD GitHub OAuth client secret version"
  type        = list(string)
  default     = ["user:r.matthias3@gmail.com"]
}

variable "ghcr_pull_token_writers" {
  description = "Principals (user:/group:) allowed to add the GHCR pull token secret version"
  type        = list(string)
  default     = ["user:r.matthias3@gmail.com"]
}
