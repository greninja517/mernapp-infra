variable "project_id" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "region" {
  type        = string
  description = "The region for the VPC resources"
}

variable "subnet_config" {
  type = object({
    name               = string
    primary_cidr       = string
    region             = string
    service_range_name = string
    service_range_cidr = string
    pod_range_name     = string
    pod_range_cidr     = string
  })
}

variable "gke_node" {
  type = object({
    service_account_id = string
    roles              = list(string)
  })
}

variable "cluster_name" {
  type        = string
  description = "value for the cluster name"
}

variable "cluster_access_cidrs" {
  type        = list(string)
  description = "CIDR range for that is allowed to access the GKE cluster API"
  default     = [""]
}

variable "node_config" {
  type = object({
    machine_type = string
    disk_size_gb = number
    preemptible  = bool
    min_count    = number
    max_count    = number
    node_tags    = list(string)
  })

}




