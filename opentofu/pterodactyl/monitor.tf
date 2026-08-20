# ---------------------------------------------------------------------------
# Beszel Agent – Monitoring Agent (Intel GPU)
# Reports to the central Beszel hub running in the main stack.
# ---------------------------------------------------------------------------
resource "docker_image" "beszel_agent" {
  name = "henrygd/beszel-agent-intel:0.18.8"
}

resource "docker_container" "beszel_agent" {
  name         = "beszel-agent"
  image        = docker_image.beszel_agent.image_id
  restart      = "unless-stopped"
  network_mode = "host"
  security_opts = ["apparmor:unconfined"]

  volumes {
    host_path      = "${var.docker_mnt}/beszel_agent_data"
    container_path = "/var/lib/beszel-agent"
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

  env = [
    "LISTEN=45876",
    "HUB_URL=${var.beszel_agent_hub_url}",
    "TOKEN=${var.beszel_agent_token}",
    "KEY=${var.beszel_agent_key}",
  ]

  # PERFMON: Intel GPU stats via intel_gpu_top
  # SYS_RAWIO / SYS_ADMIN: SMART data via smartctl
  capabilities {
    add = ["PERFMON", "SYS_RAWIO", "SYS_ADMIN"]
  }

  devices {
    host_path      = "/dev/dri/card1"
    container_path = "/dev/dri/card1"
  }
  devices {
    host_path      = "/dev/nvme0"
    container_path = "/dev/nvme0"
  }
  devices {
    host_path      = "/dev/sda"
    container_path = "/dev/sda"
  }
}

# ---------------------------------------------------------------------------
# Dozzle – Container Log Viewer
# ---------------------------------------------------------------------------
resource "docker_image" "dozzle" {
  name = "amir20/dozzle:v10.7.2"
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
