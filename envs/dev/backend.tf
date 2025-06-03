terraform {
  backend "gcs" {
    bucket = "devops-mern-461410"
    prefix = "terraform_state"
  }
}
