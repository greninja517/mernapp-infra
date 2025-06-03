# Enabling the required APIs
resource "google_project_service" "service_usage_api" {
  for_each                   = toset(var.apis)
  service                    = each.key
  disable_dependent_services = false
  disable_on_destroy         = false
}

# creating the gke cluster
module "gke_cluster" {
  source = "../../modules/gke"

  project_id           = var.project_id
  vpc_name             = var.vpc_name
  region               = var.region
  subnet_config        = var.subnet_config
  gke_node             = var.gke_node
  cluster_name         = var.cluster_name
  cluster_access_cidrs = var.cluster_access_cidrs
  node_config          = var.node_config
}