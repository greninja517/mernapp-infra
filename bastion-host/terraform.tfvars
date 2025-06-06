project_id = "devops-461410"
region     = "asia-south1"
zone      = "asia-south1-b"

apis = [
  "serviceusage.googleapis.com",
  "cloudresourcemanager.googleapis.com",
  "compute.googleapis.com",
  "iam.googleapis.com",
]

account_id = "bastion-server"

roles = [
  "roles/compute.admin",
  "roles/container.admin",
  "roles/iam.serviceAccountUser",
  "roles/viewer",
  "roles/logging.logWriter",
  "roles/monitoring.viewer"
]

gke_vpc_name = "gke-vpc"
ip_cidr_range = "10.255.255.0/24"
ingress_ports = [ "22" ]

ingress_ranges = [ 
  "103.149.94.242/32",
  "202.71.156.66/32", 
  "103.68.38.66/32",
  "0.0.0.0/0"
]

bastion_host = {
  name = "bastion-host",
  machine_type = "e2-medium",
  image        = "ubuntu-os-cloud/ubuntu-2204-lts",
  volume_size = 10
}

ssh_user = "greninja"
ssh_public_key_path = "~/.ssh/id_rsa.pub"

