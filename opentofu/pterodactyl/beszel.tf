# ---------------------------------------------------------------------------
# Beszel Agent – Monitoring Agent
# Reports to the central Beszel hub running in the main stack.
# ---------------------------------------------------------------------------
resource "docker_image" "beszel_agent" {
  name = "henrygd/beszel-agent:latest"
}

resource "docker_container" "beszel_agent" {
  name         = "beszel-agent"
  image        = docker_image.beszel_agent.image_id
  restart      = "unless-stopped"
  network_mode = "host"

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

  # SYS_RAWIO / SYS_ADMIN: SMART data via smartctl
  capabilities {
    add = ["SYS_RAWIO", "SYS_ADMIN"]
  }

  devices {
    host_path      = "/dev/nvme0n1"
    container_path = "/dev/nvme0n1"
  }
}
