# ---------------------------------------------------------------------------
# Tdarr Server + Internal Node – Transcode Automation
# ---------------------------------------------------------------------------
resource "docker_image" "tdarr" {
  name = "ghcr.io/haveagitgat/tdarr:2.89.01"
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

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.timezone}",
    "serverIP=0.0.0.0",
    "serverPort=8266",
    "webUIPort=8265",
    "internalNode=true",
    "nodeName=5070-node",
  ]

  # NVIDIA GPU (RTX 5070) via nvidia-container-toolkit — Tdarr detects
  # NVENC/NVDEC automatically; point Tdarr's hardware acceleration plugin
  # at h264_nvenc/hevc_nvenc encoders.
  gpus = "all"

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                       = "true"
      "traefik.docker.network"                               = "proxy"
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

