# ---------------------------------------------------------------------------
# Tdarr Server – Transcode Automation
# ---------------------------------------------------------------------------
resource "docker_image" "tdarr" {
  name = "ghcr.io/haveagitgat/tdarr:latest"
}

resource "docker_container" "tdarr" {
  name     = "tdarr"
  image    = docker_image.tdarr.image_id
  restart  = "unless-stopped"
  hostname = "tdarr"

  networks_advanced {
    name    = docker_network.tdarr.id
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
  name = "tdarr-node-intel:latest"

  build {
    context    = "${path.module}/dockerfiles/tdarr-node"
    dockerfile = "Dockerfile"
    tag        = ["tdarr-node-intel:latest"]
    pull_parent = true
  }

  triggers = {
    dockerfile_sha = filesha1("${path.module}/dockerfiles/tdarr-node/Dockerfile")
  }
}

resource "docker_container" "tdarr_node" {
  name     = "tdarr-node"
  image    = docker_image.tdarr_node.image_id
  restart  = "unless-stopped"
  hostname = "tdarr-node"

  networks_advanced {
    name    = docker_network.tdarr.id
    aliases = ["tdarr-node"]
  }

  env = [
    "PUID=${var.puid}",
    "PGID=${var.pgid}",
    "TZ=${var.timezone}",
    "serverIP=tdarr",
    "serverPort=8266",
    "nodeName=a310-node",
  ]

  # Intel A310 only — bind only the A310's render node, remapped to the
  # default path so QSV picks it. Mounting iGPU's card alongside breaks
  # libva topology checks. Verify mapping with: ls -la /dev/dri/by-path/
  devices {
    host_path      = "/dev/dri/renderD129"
    container_path = "/dev/dri/renderD128"
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
