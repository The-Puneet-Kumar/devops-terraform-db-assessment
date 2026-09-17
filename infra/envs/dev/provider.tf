provider "aws" {
  region = var.aws_region

  # Allows review/plan workflows without performing AWS API discovery.
  # Remove these flags for a normal live AWS deployment.
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}
