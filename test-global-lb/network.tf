data "http" "myip" {
  url = "https://ifconfig.co/ip"
}

# VPC Section
resource "google_compute_network" "vpc" {
  name                    = "${local.prefix}${var.vpc_name}"
  auto_create_subnetworks = "false"
  project                 = local.gcp_project_id
}

/*
# LOAD BALANCER CONFIGURATION */
# Reserve External IP address for the load balancer

resource "google_compute_global_address" "cac-global-ip" {
  name = "${local.prefix}global-cac-ip"
}

# Create the health check
resource "google_compute_http_health_check" "cac-health-check" {
  name = "${local.prefix}cac-health-check"
  request_path = "/health"

  check_interval_sec = 3
  timeout_sec = 3
  healthy_threshold = 2
  unhealthy_threshold = 2

}

# Specify what paths (if any) should be load balanced along with any path based routing rules.
resource "google_compute_url_map" "cac-url-map" {
  ## count         = length(var.cac_region_list)
  name = "${local.prefix}cac-url-map"
  default_service = google_compute_backend_service.cac-backend-service.self_link

  host_rule {
    hosts = ["*"]
    path_matcher = "cac-allpaths"
  }

  path_matcher {
    name = "cac-allpaths"
    default_service = google_compute_backend_service.cac-backend-service.self_link
  }

}

## Create a target http proxy: https://cloud.google.com/load-balancing/docs/target-proxies
resource "google_compute_target_http_proxy" "cac-http-proxy" {
  ## count         = length(var.cac_region_list)
  name = "${local.prefix}cac-http-proxy"
  url_map = google_compute_url_map.cac-url-map.self_link
}

## Create a forwarding rule to the proxy with the external IP address reserved above
resource "google_compute_global_forwarding_rule" "cac-global-fw-rule" {
  name = "${local.prefix}cac-global-fw-rule"
  target = google_compute_target_http_proxy.cac-http-proxy.self_link
  ip_address = google_compute_global_address.cac-global-ip.address
  port_range = "80"
}

# Configure the backend to point to the respective regional MIG
resource "google_compute_backend_service" "cac-backend-service" {
  ## count         = length(var.cac_region_list)
  name      = "${local.prefix}cac-backend-service"
  port_name = "http"
  protocol  = "HTTP"
  health_checks = [ google_compute_http_health_check.cac-health-check.id ]

  backend {
    balancing_mode = "UTILIZATION"
    group          = module.cac-mig.instance_group
  }
}


# Subnetwork section
resource "google_compute_subnetwork" "cac_subnet" {
  ## count         = length(var.cac_region_list)
  ## name          = "${local.prefix}${var.vpc_name}-cac-${var.cac_region_list[count.index]}"
  name          = "${local.prefix}${var.vpc_name}-cac-${var.cac_region}"
  ## ip_cidr_range = cidrsubnet(var.cac_subnet_cidr_start_range, 8, count.index)
  ip_cidr_range = "192.168.0.0/24"
  network       = google_compute_network.vpc.name
  project       = local.gcp_project_id
}

# Firewall rules
resource "google_compute_firewall" "allow-external" {
  name    = "${local.prefix}fw-allow-external"
  network = google_compute_network.vpc.self_link
  project = local.gcp_project_id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags   = ["${local.prefix}fw-allow-external"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-iap" {
  name    = "${local.prefix}fw-allow-iap"
  network = google_compute_network.vpc.self_link
  project = local.gcp_project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["${local.prefix}fw-allow-iap"]
  source_ranges = ["35.235.240.0/20"]
}

##### CLOUD ROUTER AND NAT FOR INTERNET ACCESS

resource "google_compute_router" "router" {
  ## count = length(var.cac_region_list)
  ## name    = "${local.prefix}router-${var.cac_region_list[count.index]}"
  name    = "${local.prefix}router-${var.cac_region}"
  ## region  = var.cac_region_list[count.index]
  region  = var.cac_region
  network = google_compute_network.vpc.self_link

  bgp {
    asn = 65000
  }
}

resource "google_compute_router_nat" "nat" {
  ## count = length(var.cac_region_list)
  ## name                               = "${local.prefix}nat-${var.cac_region_list[count.index]}"
  ## router                             = google_compute_router.router[count.index].name
  ## region                             = var.cac_region_list[count.index]
  name                               = "${local.prefix}nat-${var.cac_region}"
  router                             = google_compute_router.router.name
  region                             = var.cac_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  min_ports_per_vm                   = 2048

  subnetwork {
    ## name                    = google_compute_subnetwork.cac_subnet[count.index].self_link
    name                    = google_compute_subnetwork.cac_subnet.self_link
    source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE"]
  }
}