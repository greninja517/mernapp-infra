output "Cluster_name" {
  value = module.gke_cluster.Cluster_name
}

output "Cluster_endpoint" {
  value       = module.gke_cluster.Cluster_endpoint
  description = "Endpoint for the GKE cluster"
}