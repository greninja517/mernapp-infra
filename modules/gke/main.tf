# Creating the VPC 
resource "google_compute_network" "vpc_network" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Creating the subnet
resource "google_compute_subnetwork" "vpc_subnet" {
  name                     = var.subnet_config.name
  ip_cidr_range            = var.subnet_config.primary_cidr
  region                   = var.region
  network                  = google_compute_network.vpc_network.id
  private_ip_google_access = true

  # Secondary IP ranges for services
  secondary_ip_range {
    range_name    = var.subnet_config.service_range_name
    ip_cidr_range = var.subnet_config.service_range_cidr
  }

  # Secondary IP ranges for pods
  secondary_ip_range {
    range_name    = var.subnet_config.pod_range_name
    ip_cidr_range = var.subnet_config.pod_range_cidr
  }

  depends_on = [google_compute_network.vpc_network]
}

# Creating the Cloud Router Needed for NAT
resource "google_compute_router" "vpc_router" {
  name    = "${var.vpc_name}-router"
  network = google_compute_network.vpc_network.id
  region  = var.region
  bgp {
    asn = 64514
  }

  depends_on = [google_compute_network.vpc_network]
}

# Creating the Cloud NAT for private GKE Nodes and Pods
resource "google_compute_router_nat" "vpc_nat" {
  name   = "${var.vpc_name}-nat"
  router = google_compute_router.vpc_router.name
  region = var.region

  nat_ip_allocate_option = "AUTO_ONLY"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  # Enable NAT for pod IPs and Node IPs
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name = google_compute_subnetwork.vpc_subnet.self_link
    source_ip_ranges_to_nat = [
      "PRIMARY_IP_RANGE",
      "LIST_OF_SECONDARY_IP_RANGES"
    ]
    secondary_ip_range_names = [
      var.subnet_config.pod_range_name
    ]
  }

  depends_on = [google_compute_router.vpc_router]
}

# Creating the Firewall Rules for GKE VPC
resource "google_compute_firewall" "gke_internal" {
  name      = "gke-allow-internal"
  network   = google_compute_network.vpc_network.name
  direction = "INGRESS"
  priority  = 1000

  source_ranges = [
    var.subnet_config.primary_cidr,
    var.subnet_config.service_range_cidr,
    var.subnet_config.pod_range_cidr
  ]

  allow {
    protocol = "all"
  }
}

resource "google_compute_firewall" "gke_allow_control_plane" {
  name      = "gke-allow-control-plane"
  network   = google_compute_network.vpc_network.name
  direction = "INGRESS"
  priority  = 1000

  # GKE Control Plane Public IPs and LBs for health checks
  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]

  allow {
    protocol = "tcp"
    ports    = ["443", "10250", "30000-32767"]
  }

  target_tags = var.node_config.node_tags
}

resource "google_compute_firewall" "allow_all_egress" {
  name     = "allow-all-egress"
  network  = google_compute_network.vpc_network.name
  priority = 1000

  allow {
    protocol = "all"
  }
  direction          = "EGRESS"
  destination_ranges = ["0.0.0.0/0"]
  target_tags        = var.node_config.node_tags
}

# Creating a Service Account for GKE Nodes
resource "google_service_account" "gke_node_sa" {
  account_id                   = var.gke_node.service_account_id
  display_name                 = "GKE Nodes Service Account"
  description                  = "Service account for GKE Nodes"
  create_ignore_already_exists = true
}


# Assigning roles to the GKE Node Service Account
resource "google_project_iam_member" "gke_node_sa_roles" {
  for_each   = toset(var.gke_node.roles)
  project    = var.project_id
  role       = each.value
  member     = "serviceAccount:${google_service_account.gke_node_sa.email}"
  depends_on = [google_service_account.gke_node_sa]
}

# Creating the GKE Cluster
resource "google_container_cluster" "primary_cluster" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  deletion_protection = false
  network             = google_compute_network.vpc_network.self_link
  subnetwork          = google_compute_subnetwork.vpc_subnet.self_link

  ip_allocation_policy {
    cluster_secondary_range_name  = var.subnet_config.pod_range_name
    services_secondary_range_name = var.subnet_config.service_range_name
  }

  release_channel {
    channel = "REGULAR"
  }

  # terraform will remove the default node pool that is created by GKE
  remove_default_node_pool = true

  #  for the regional clusters, the initial_node_count defines the no. of nodes to
  # create in each zone for the defaul node pool that is automatically created
  initial_node_count       = 1
  node_config {
    disk_type = "pd-standard"
    disk_size_gb = 15
    machine_type = "e2-small"
    service_account = google_service_account.gke_node_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  # public API Endpoint but private nodes
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_global_access_config {
      enabled = true
    }
  }

  # controlling the acces to API endpoint; only the mentioned CIDR blocks can access the API
  master_authorized_networks_config {

    dynamic "cidr_blocks" {
      for_each = var.cluster_access_cidrs
      iterator = cidr_item
      content {
        cidr_block   = cidr_item.value
        display_name = "authorized network-${cidr_item.key}"
      }
    }
  }

  # enabling the ingress-controller addon i.e. HTTP Load Balancing that will automatically deploy an Ingress controller
  addons_config {
    http_load_balancing {
      disabled = false
    }
  }
}

resource "google_container_node_pool" "worker_nodes" {
  name       = "first-node-pool"
  cluster    = google_container_cluster.primary_cluster.name
  location   = var.region
  # node_count = 1 # it means 1 node per zone for regional clusters
  # not needed as we are using autoscaling

  autoscaling {
    total_min_node_count = 1 # total minimum nodes across all zones for regional clusters
    total_max_node_count = 1 # total maximum nodes across all zones for regional clusters
  }

  node_config {
    disk_type = "pd-standard"
    disk_size_gb = var.node_config.disk_size_gb
    preemptible  = var.node_config.preemptible
    machine_type = var.node_config.machine_type
    tags         = var.node_config.node_tags


    service_account = google_service_account.gke_node_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}










