# Variable file for Instance objects
variable "prefix" {
  type        = string
  description = "Prefix to be used for resource naming including instances"
  default     = "lqt"
}

variable "gcp_region" {
  type        = string
  description = "(optional) describe your variable"
  default     = "us-central1"
}

variable "gcp_zone" {
  type        = string
  description = "(optional) describe your variable"
  default     = "us-central1-a"
}

variable "gcp_credentials_file" {
  type        = string
  description = "Name and path to the service account credentials file"
  default     = "./svc-account/sada-lancy-internal-dev-prj-485eddc093c5.json"
}

variable "metadata_startup_script" {
  type    = string
  default = <<EOF
    sudo apt update && sudo apt -y install git gunicorn3 python3-pip
    git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git
    cd python-docs-samples/compute/managed-instances/demo
    sudo pip3 install -r requirements.txt
    sudo gunicorn3 --bind 0.0.0.0:80 app:app --daemon
    EOF
}
# variable "network_tags" {
#     type = list(string)
#     description = "(optional) describe your variable"
#     default = null
# }
variable "cac_region_list" {
  type        = list(string)
  description = "Regions where the CAC needs to be deployed"
  default     = ["us-central1"]
}

variable "cac_region" {
  type        = string
  description = "Region where the CAC needs to be deployed - DEBUG ONLY - USE LIST VAR"
  default     = "us-central1"
}

variable "gcp_update_policy" {
  type = list(object({
    max_surge_fixed              = number
    instance_redistribution_type = string
    max_surge_percent            = number
    max_unavailable_fixed        = number
    max_unavailable_percent      = number
    min_ready_sec                = number
    minimal_action               = string
    type                         = string
  }))
  description = "Update policy for the instance group"
  default = [{
    max_surge_fixed              = 4
    instance_redistribution_type = "PROACTIVE"
    max_surge_percent            = null
    max_unavailable_fixed        = 4
    max_unavailable_percent      = null
    min_ready_sec                = 30
    minimal_action               = "REPLACE"
    type                         = "PROACTIVE"
  }]
}


variable "compute_service_account" {
  description = "Service account used by compute instances"
  type = object({
    email  = string
    scopes = set(string)
  })
  default = {
    email  = "lq-compute-svc-acc-01@sada-lancy-internal-dev-prj.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC to create"
  default     = "mig-vpc"
}

variable "dc_subnet_cidr" {
  description = "CIDR range for the Domain Controller Subnet - used for firewall rules"
  default     = "192.168.0.0/24"
}

# variable cac_subnet_cidr {
#     description = "CIDR range for the CAC machines - used in subnetwork creation"
#     default = "192.168.0.0/24"
# }

variable "cac_subnet_cidr_start_range" {
  description = "CIDR range for the CAC"
  default     = "192.168.0.0/16"
}

variable "ws_subnet_cidr_list" {
  description = "CIDR range containing the workstations"
  default     = "192.168.2.0/24"
}