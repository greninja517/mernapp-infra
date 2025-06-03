output "Cluster_name" {
  value = google_container_cluster.primary_cluster.name
}

output "Cluster_endpoint" {
  value = google_container_cluster.primary_cluster.endpoint
  description = "The endpoint for the GKE cluster"
}