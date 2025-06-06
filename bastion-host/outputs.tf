output "bastion_host_public_ip" {
  value = "${google_compute_instance.bastion_host.network_interface[0].access_config[0].nat_ip}"
}