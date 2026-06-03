#!/bin/bash
set -euo pipefail

PROJECT_ID="carbon-zone-496411-s6"
REGION="europe-west3"
BUCKET_NAME="${PROJECT_ID}-terraform-state"

echo "Creating Terraform state bucket: ${BUCKET_NAME}"

gcloud storage buckets create "gs://${BUCKET_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${REGION}" \
  --uniform-bucket-level-access

gcloud storage buckets update "gs://${BUCKET_NAME}" \
  --versioning

echo "Bucket created: gs://${BUCKET_NAME}"
echo "Run 'terraform init' to initialize the backend."
