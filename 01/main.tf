terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "3.0.1"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Pulls the image
resource "docker_image" "apache_web" {
  name  = "httpd:latest"
}

# Create a container
resource "docker_container" "web_server" {
  image = docker_image.apache_web.image_id
  name  = "web_server"
  ports {
    internal = 80
    external = 88
  }
}
