terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.2"
    }
  }
}

provider "docker" {
  host = "tcp://localhost:2375"
}

# Pull the image
resource "docker_image" "httpd" {
  name = "httpd:latest"
}

# Create a container
resource "docker_container" "webserver" {
  image = docker_image.httpd.image_id
  name  = "webserver"
  ports {
    internal = 80
    external = 8080
  }
}


