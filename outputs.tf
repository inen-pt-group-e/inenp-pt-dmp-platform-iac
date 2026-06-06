output "terraform_state_bucket" {
  description = "GCS bucket used for Terraform remote state"
  value       = "gs://carbon-zone-496411-s6-terraform-state"
}

output "vpc_name" {
  description = "Name of the platform VPC"
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "Name of the platform subnet"
  value       = google_compute_subnetwork.subnet.name
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.platform.name
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = google_container_cluster.platform.location
}

output "dns_nameservers" {
  description = "Nameservers for mcce-project.xyz — configure these at your domain registrar"
  value       = google_dns_managed_zone.platform.name_servers
}

output "workload_identity_provider" {
  description = "WIF provider resource name for GitHub Actions auth"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "terraform_pipeline_sa_email" {
  description = "Email of the Terraform pipeline service account"
  value       = google_service_account.terraform_pipeline.email
}
