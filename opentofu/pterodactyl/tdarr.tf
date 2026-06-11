# ---------------------------------------------------------------------------
# Tdarr Server – Transcode Automation
# ---------------------------------------------------------------------------
resource "docker_image" "tdarr" {
  name = "ghcr.io/haveagitgat/tdarr:2.77.01"
}

resource "docker_container" "tdarr" {
  name     = "tdarr"
  image    = docker_image.tdarr.image_id
  restart  = "unless-stopped"
  hostname = "tdarr"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["tdarr"]
  }

  ports {
    internal = 8265
    external = 8265
  }
  ports {
    internal = 8266
    external = 8266
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.timezone}",
    "serverIP=0.0.0.0",
    "serverPort=8266",
    "webUIPort=8265",
    "internalNode=false",
  ]

  volumes {
    host_path      = "${var.docker_mnt}/tdarr/server"
    container_path = "/app/server"
  }
  volumes {
    host_path      = "${var.docker_mnt}/tdarr/configs"
    container_path = "/app/configs"
  }
  volumes {
    host_path      = "${var.docker_mnt}/tdarr/logs"
    container_path = "/app/logs"
  }
  volumes {
    volume_name    = docker_volume.media_library_nfs.name
    container_path = "/media"
  }
  volumes {
    host_path      = var.tdarr_transcode_cache
    container_path = "/temp"
  }

  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
  }
}

# ---------------------------------------------------------------------------
# Tdarr Node – Transcode Worker (Intel QSV via A310)
# ---------------------------------------------------------------------------
resource "docker_image" "tdarr_node" {
  name = "ghcr.io/haveagitgat/tdarr_node:2.77.01"
}

resource "docker_container" "tdarr_node" {
  name     = "tdarr-node"
  image    = docker_image.tdarr_node.image_id
  restart  = "unless-stopped"
  hostname = "tdarr-node"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["tdarr-node"]
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.timezone}",
    "serverIP=tdarr",
    "serverPort=8266",
    "nodeName=a310-node",
    "LIBVA_DRIVER_NAME=iHD",
  ]

  # Intel A310 — mount the A310's render node at its native path. Remapping
  # to renderD128 breaks libva's DRM topology lookup (vaGetDisplayDRM returns
  # NULL). Tdarr flow plugins must point QSV/VAAPI at /dev/dri/renderD129.
  devices {
    host_path      = "/dev/dri/renderD129"
    container_path = "/dev/dri/renderD129"
  }

  devices {
    host_path      = "/dev/dri/card1"
    container_path = "/dev/dri/card1"
  }

  volumes {
    host_path      = "${var.docker_mnt}/tdarr/configs"
    container_path = "/app/configs"
  }
  volumes {
    host_path      = "${var.docker_mnt}/tdarr/logs"
    container_path = "/app/logs"
  }
  volumes {
    volume_name    = docker_volume.media_library_nfs.name
    container_path = "/media"
  }
  volumes {
    host_path      = var.tdarr_transcode_cache
    container_path = "/temp"
  }

  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
  }

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                        = "true"
      "traefik.http.routers.tdarr.rule"                      = "Host(`tdarr.local.uaccloud.com`)"
      "traefik.http.routers.tdarr.entrypoints"               = "websecure"
      "traefik.http.services.tdarr.loadbalancer.server.port" = "8265"
      "traefik.http.routers.tdarr.tls"                       = "true"
      "traefik.http.routers.tdarr.tls.certresolver"          = "cloudflare"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}
