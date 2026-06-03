output "terraform_state_bucket" {
  description = "GCS bucket used for Terraform remote state"
  value       = "gs://carbon-zone-496411-s6-terraform-state"
}
