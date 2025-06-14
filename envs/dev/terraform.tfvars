project_id = "devops-461410"
vpc_name   = "gke-vpc"
region     = "asia-south1"

subnet_config = {
  name               = "gke-subnet"
  primary_cidr       = "192.168.0.0/20"
  region             = "asia-south1"
  service_range_name = "services"
  service_range_cidr = "192.168.16.0/20"
  pod_range_name     = "pods"
  pod_range_cidr     = "192.168.32.0/20"
}

gke_node = {
  service_account_id = "gke-nodes-sa"
  roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/artifactregistry.reader",
    "roles/container.nodeServiceAccount"
  ]
}

cluster_name = "mern-cluster"

cluster_access_cidrs = [
  "103.149.94.242/32",
  "202.71.156.66/32",
  "103.68.38.66/32",
  "0.0.0.0/0"
]

node_count = {
  max = 2
  min = 1
}

node_config = {
  machine_type = "e2-medium"
  disk_size_gb = 20
  preemptible  = true
  node_tags    = ["gke-node"]
}


apis = [
  "serviceusage.googleapis.com",
  "compute.googleapis.com",
  "container.googleapis.com",
  "storage.googleapis.com",
  "iam.googleapis.com",
  "artifactregistry.googleapis.com",
  "cloudresourcemanager.googleapis.com"
]


