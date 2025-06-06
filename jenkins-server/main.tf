# Enabling the required API services
resource "google_project_service" "service_usage_api" {
  for_each                   = toset(var.apis)
  service                    = each.key
  disable_dependent_services = false
  disable_on_destroy         = false
}

# Creating a Service Account for Jenkins Server
resource "google_service_account" "jenkins_sa" {
  account_id                   = var.account_id
  display_name                 = "Jenkins Server Service Account"
  description                  = "Service account for Jenkins server operations"
  create_ignore_already_exists = true
  depends_on                   = [google_project_service.service_usage_api]
}

# Assigning roles to the Jenkins Service Account
resource "google_project_iam_member" "jenkins_sa_roles" {
  for_each   = toset(var.roles)
  project    = var.project_id
  role       = each.value
  member     = "serviceAccount:${google_service_account.jenkins_sa.email}"
  depends_on = [google_service_account.jenkins_sa]
}

resource "google_compute_network" "jenkins_vpc" {
  name                    = "jenkins-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.service_usage_api]
}

resource "google_compute_subnetwork" "jenkins_subnet" {
  name          = "jenkins-subnet"
  ip_cidr_range = "192.168.0.0/20"
  region        = var.region
  network       = google_compute_network.jenkins_vpc.id
}

resource "google_compute_firewall" "jenkins_ingress" {
  name    = "jenkins-ingress"
  network = google_compute_network.jenkins_vpc.name

  allow {
    protocol = "tcp"
    ports    = var.ingress_ports
  }
  direction     = "INGRESS"
  source_ranges = var.ingress_ranges
  target_tags   = ["jenkins-server"]
}

resource "google_compute_firewall" "jenkins_egress" {
  name    = "jenkins-egress"
  network = google_compute_network.jenkins_vpc.name

  allow {
    protocol = "all"
  }
  direction          = "EGRESS"
  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["jenkins-server"]
}

resource "google_compute_instance" "jenkins_server" {
  name         = var.jenkins_server.name
  machine_type = var.jenkins_server.machine_type
  zone         = var.zone
  tags         = ["jenkins-server"]

  boot_disk {
    initialize_params {
      image = var.jenkins_server.image
      size  = var.jenkins_server.volume_size
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.jenkins_subnet.name
    access_config {}
  }

  service_account {
    email  = google_service_account.jenkins_sa.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true

  metadata_startup_script = file("./startup-script.sh")

  depends_on = [
    google_compute_firewall.jenkins_ingress,
    google_compute_firewall.jenkins_egress,
    google_project_service.service_usage_api
  ]

}

