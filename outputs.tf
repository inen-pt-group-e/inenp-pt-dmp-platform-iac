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