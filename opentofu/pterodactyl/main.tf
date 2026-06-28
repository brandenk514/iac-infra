terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "registry.opentofu.org/kreuzwerker/docker"
      version = "~> 4.0"
    }
  }

  backend "s3" {}
}

provider "docker" {
  host = "ssh://${var.ssh_user}@${var.ssh_host}:${var.ssh_port}"
  registry_auth {
    address  = "https://index.docker.io/v1/"
    username = var.dockerhub_username
    password = var.dockerhub_password
  }
}
