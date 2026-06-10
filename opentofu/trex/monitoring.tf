# ---------------------------------------------------------------------------
# Dozzle – Container Log Viewer
# ---------------------------------------------------------------------------
resource "docker_image" "dozzle" {
  name = "amir20/dozzle:v10.6.5"
}

resource "docker_container" "dozzle" {
  name    = "dozzle"
  image   = docker_image.dozzle.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["dozzle"]
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  env = [
    "DOZZLE_ENABLE_ACTIONS=true",
    "DOZZLE_ENABLE_SHELL=true",
  ]

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                     = "true"
      "traefik.http.routers.dozzle.rule"                   = "Host(`dozzle.local.uaccloud.com`)"
      "traefik.http.services.dozzle.loadbalancer.server.port" = "8080"
      "traefik.http.routers.dozzle.tls"                    = "true"
      "traefik.http.routers.dozzle.tls.certresolver"       = "cloudflare"
      "traefik.http.routers.dozzle.entrypoints"            = "websecure"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}
