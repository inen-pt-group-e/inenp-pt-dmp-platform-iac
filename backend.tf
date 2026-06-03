terraform {
  backend "gcs" {
    bucket = "carbon-zone-496411-s6-terraform-state"
    prefix = "terraform/state"
  }
}
