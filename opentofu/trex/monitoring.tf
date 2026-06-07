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

# ---------------------------------------------------------------------------
# Beszel Agent – Monitoring Agent (NVIDIA-enabled)
# ---------------------------------------------------------------------------
resource "docker_image" "beszel_agent" {
  name = "henrygd/beszel-agent-nvidia:0.18.7"
}

resource "docker_container" "beszel_agent" {
  name         = "beszel-agent"
  image        = docker_image.beszel_agent.image_id
  restart      = "unless-stopped"
  network_mode = "host"
  security_opts = ["apparmor:unconfined"]

  device_requests {
    driver     = "cdi"
    device_ids = ["nvidia.com/gpu=all"]
  }

  volumes {
    host_path      = "${var.docker_mnt}/beszel_agent_data"
    container_path = "/var/lib/beszel-agent"
  }
  volumes {
    host_path      = "${var.docker_mnt}/beszel_socket"
    container_path = "/beszel_socket"
  }
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }
  volumes {
    host_path      = "/var/run/dbus/system_bus_socket"
    container_path = "/var/run/dbus/system_bus_socket"
    read_only      = true
  }
  volumes {
    host_path      = "/mnt/r5-dstor/.beszel"
    container_path = "/extra-filesystems/md0"
    read_only      = true
  }

  env = [
    "LISTEN=/beszel_socket/beszel.sock",
    "HUB_URL=${var.beszel_agent_hub_url}",
    "TOKEN=${var.beszel_agent_token}",
    "KEY=${var.beszel_agent_key}",
  ]

  capabilities {
    add = ["SYS_RAWIO", "SYS_ADMIN"]
  }

  devices {
    host_path      = "/dev/sda"
    container_path = "/dev/sda"
  }
  devices {
    host_path      = "/dev/sdb"
    container_path = "/dev/sdb"
  }
  devices {
    host_path      = "/dev/sdc"
    container_path = "/dev/sdc"
  }
  devices {
    host_path      = "/dev/sdd"
    container_path = "/dev/sdd"
  }
  devices {
    host_path      = "/dev/sde"
    container_path = "/dev/sde"
  }
  devices {
    host_path      = "/dev/sdf"
    container_path = "/dev/sdf"
  }
  devices {
    host_path      = "/dev/nvme0"
    container_path = "/dev/nvme0"
  }
}
