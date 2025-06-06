# Enabling the required API services
resource "google_project_service" "service_usage_api" {
  for_each                   = toset(var.apis)
  service                    = each.key
  disable_dependent_services = false
  disable_on_destroy         = false
}

# Creating a Service Account for Bastion Host
resource "google_service_account" "bastion_host_sa" {
  account_id                   = var.account_id
  display_name                 = "Bastion Host Service Account"
  description                  = "Service account for Bastion Host operations"
  create_ignore_already_exists = true
  depends_on                   = [google_project_service.service_usage_api]
}

# Assigning roles to the Bastion Host Service Account
resource "google_project_iam_member" "bastion_sa_roles" {
  for_each   = toset(var.roles)
  project    = var.project_id
  role       = each.value
  member     = "serviceAccount:${google_service_account.bastion_host_sa.email}"
  depends_on = [google_service_account.bastion_host_sa]
}

# Retrieving the GKE VPC
data "google_compute_network" "gke_vpc" {
  name = var.gke_vpc_name
}

# Creating a Subnetwork for the Bastion Host
resource "google_compute_subnetwork" "bastion_subnet" {
  name          = "bastion-subnet"
    ip_cidr_range = var.ip_cidr_range
  region        = var.region
  network       = data.google_compute_network.gke_vpc.id
}

# Creating the Ingress Firewall Rule for the Bastion Host
resource "google_compute_firewall" "bastion_ingress" {
  name    = "bastion-ingress"
  network = data.google_compute_network.gke_vpc.name

  allow {
    protocol = "tcp"
    ports    = var.ingress_ports
  }
  direction     = "INGRESS"
  source_ranges = var.ingress_ranges
  target_tags   = ["bastion-server"]

  depends_on = [ google_compute_subnetwork.bastion_subnet ]
}

# Creating the Egress Firewall Rule for the Bastion Host
resource "google_compute_firewall" "bastion_egress" {
  name    = "bastion-egress"
  network = data.google_compute_network.gke_vpc.name

  allow {
    protocol = "all"
  }
  direction          = "EGRESS"
  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["bastion-server"]

  depends_on = [ google_compute_subnetwork.bastion_subnet ]
}

# Creating the Bastion Host instance
resource "google_compute_instance" "bastion_host" {
  name         = var.bastion_host.name
  machine_type = var.bastion_host.machine_type
  zone         = var.zone
  tags         = ["bastion-server"]

  boot_disk {
    initialize_params {
      image = var.bastion_host.image
      size  = var.bastion_host.volume_size
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.bastion_subnet.name
    access_config {}
  }

  service_account {
    email  = google_service_account.bastion_host_sa.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true

  metadata_startup_script = file("./startup-script.sh")

  metadata = {
  ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
    }


  depends_on = [
    google_compute_firewall.bastion_ingress,
    google_compute_firewall.bastion_egress,
    google_project_service.service_usage_api
  ]

}