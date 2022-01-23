locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
  # bucket_name = "${local.prefix}pcoip-scripts-${random_id.bucket-name.hex}"
  # Name of CAM deployment service account key file in bucket
  cam_deployment_sa_file = "cam-deployment-sa-key.json"

  gcp_service_account = jsondecode(file(var.gcp_credentials_file))["client_email"]
  gcp_project_id      = jsondecode(file(var.gcp_credentials_file))["project_id"]
  gcp_named_ports = [{
    name = "cac-http"
    port = 80
  }]
}

/* Allow Logwriter permissions to the compute service account */
resource "google_project_iam_member" "gcp-compute-svc-acc-iam" {
  member  = "serviceAccount:${var.compute_service_account.email}"
  role    = "roles/logging.logWriter"
  project = local.gcp_project_id
}


module "cac-instance_template" {
  ## count                = length(var.cac_region_list)
  source               = "./modules/instance_template"
  project_id           = local.gcp_project_id
  ## subnetwork           = google_compute_subnetwork.cac_subnet[count.index].name
  subnetwork           = google_compute_subnetwork.cac_subnet.name
  service_account      = var.compute_service_account
  source_image_family  = "debian-10"
  source_image_project = "debian-cloud"
  tags                 = [google_compute_firewall.allow-external.name, google_compute_firewall.allow-iap.name]
  startup_script       = var.metadata_startup_script
  name_prefix          = "${local.prefix}tpl"
  metadata = {
    osLogin = "true"
  }
}

module "cac-mig" {
  ## count               = length(var.cac_region_list)
  source              = "./modules/mig"
  project_id          = local.gcp_project_id
  ## subnetwork          = google_compute_subnetwork.cac_subnet[count.index].name
  subnetwork          = google_compute_subnetwork.cac_subnet.name
  hostname            = "${local.prefix}vm"
  autoscaling_enabled = false
  region              = var.gcp_region
  ## instance_template   = module.cac-instance_template[count.index].self_link
  instance_template   = module.cac-instance_template.self_link
  target_size         = 6
  update_policy       = var.gcp_update_policy
  named_ports         = local.gcp_named_ports
}