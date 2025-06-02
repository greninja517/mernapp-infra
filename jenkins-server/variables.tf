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
  description = "Jenkins Service Account ID"
}

variable "roles" {
  type        = list(string)
  description = "List of roles to assign to the Jenkins Service Account"
}

variable "ingress_ranges" {
  type        = list(string)
  description = "List of IP ranges allowed to access the Jenkins server"
  default     = ["157.32.194.188/32"]
}

variable "jenkins_server" {
  type = object({
    name         = string
    machine_type = string
    volume_size  = number
    image        = string
  })
}