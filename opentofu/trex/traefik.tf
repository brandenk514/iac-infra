# ---------------------------------------------------------------------------
# Traefik – Reverse Proxy
# ---------------------------------------------------------------------------
resource "docker_image" "traefik" {
  name = "docker.io/library/traefik:v3.7.4"
}

resource "docker_container" "traefik" {
  name    = "traefik"
  image   = docker_image.traefik.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["traefik"]
  }

  networks_advanced {
    name    = docker_network.immich.id
    aliases = ["traefik"]
  }

  ports {
    internal = 80
    external = 80
  }
  ports {
    internal = 443
    external = 443
  }
  ports {
    internal = 8080
    external = 8080
  }
  ports {
    internal = 42069
    external = 42069
  }

  volumes {
    host_path      = "/etc/localtime"
    container_path = "/etc/localtime"
    read_only      = true
  }
  volumes {
    host_path      = "/run/docker.sock"
    container_path = "/run/docker.sock"
    read_only      = true
  }
  volumes {
    host_path      = "${var.docker_mnt}/traefik/confs/traefik.yml"
    container_path = "/traefik.yml"
    read_only      = true
  }
  volumes {
    host_path      = "${var.docker_mnt}/traefik/certs"
    container_path = "/var/traefik/certs"
  }
  volumes {
    host_path      = "${var.docker_mnt}/traefik/confs/config.yml"
    container_path = "/config.yml"
    read_only      = true
  }

  security_opts = ["no-new-privileges:true"]

  env = [
    "TRAEFIK_DASHBOARD_CREDENTIALS=${var.traefik_dashboard_credentials}",
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.timezone}",
    "CF_DNS_API_TOKEN=${var.cf_dns_api_token}",
  ]

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                    = "true"
      "traefik.http.routers.traefik.rule"                 = "Host(`traefik.local.uaccloud.com`)"
      "traefik.http.routers.traefik.tls"                  = "true"
      "traefik.http.routers.traefik.tls.certresolver"     = "cloudflare"
      "traefik.http.routers.traefik.entrypoints"          = "websecure"
      "traefik.http.middlewares.traefik.basicauth.users"  = var.traefik_dashboard_credentials
      "traefik.http.routers.traefik.middlewares"           = "traefik"
      "traefik.http.routers.traefik.tls.domains[0].main" = "uaccloud.com"
      "traefik.http.routers.traefik.tls.domains[0].sans" = "*.uaccloud.com"
      "traefik.http.routers.traefik.service"              = "api@internal"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}
