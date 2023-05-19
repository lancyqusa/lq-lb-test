provider "google" {
#  credentials = file(var.gcp_credentials_file)
  project     = local.gcp_project_id
  region      = var.gcp_region
  zone        = var.gcp_zone
}