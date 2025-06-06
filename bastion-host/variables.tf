variable "project_id" {
  type = string
} 

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "apis" {
  type        = list(string)
  description = "values are the APIs to enable for the project"
}

variable "account_id" {
  type        = string
  description = "Bastion Host Service Account ID"
}

variable "roles" {
  type        = list(string)
  description = "List of roles to assign to the Bastion Host Service Account"
}

variable "gke_vpc_name" {
  type        = string
  description = "Name of the GKE VPC to launch the Bastion Host"
}

variable "ip_cidr_range" {
  type        = string
  description = "IP CIDR range for the Bastion Host subnetwork"
  default = "10.255.255.0/24"
}

variable "ingress_ports" {
  type        = list(string)
  description = "List of ports allowed for ingress traffic to the Bastion host"  
}

variable "ingress_ranges" {
  type        = list(string)
  description = "List of IP ranges allowed to access the Bastion Host"
}

variable "bastion_host" {
  type = object({
    name         = string
    machine_type = string
    volume_size  = number
    image        = string
  })
}

variable "ssh_user" {
  type        = string
  description = "SSH user for the Bastion Host"  
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to the SSH public key for the Bastion Host"
  default     = "~/.ssh/id_rsa.pub"
}
