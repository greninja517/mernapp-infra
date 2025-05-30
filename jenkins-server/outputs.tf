output "jenkins_server_url" {
  value = "http://${google_compute_instance.jenkins_server.network_interface[0].access_config[0].nat_ip}:8080"
}