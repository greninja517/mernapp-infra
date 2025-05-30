project_id = "devops-461410"
region     = "asia-south1"
zone       = "asia-south1-b"
apis = [
  "serviceusage.googleapis.com",
  "cloudresourcemanager.googleapis.com",
  "compute.googleapis.com",
  "iam.googleapis.com",
]
account_id = "jenkins-infra-manager"

roles = [
  "roles/compute.admin",
  "roles/container.admin",
  "roles/artifactregistry.admin",
  "roles/storage.admin",
]

jenkins_server = {
  image        = "ubuntu-os-cloud/ubuntu-2204-lts",
  name         = "jenkins-ci-server",
  machine_type = "e2-medium",
  volume_size  = 15
}