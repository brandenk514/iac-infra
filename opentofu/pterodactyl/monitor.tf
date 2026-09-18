# ---------------------------------------------------------------------------
# Beszel Agent – Monitoring Agent (NVIDIA GPU)
# Reports to the central Beszel hub running in the main stack.
# ---------------------------------------------------------------------------
resource "docker_image" "beszel_agent" {
  name = "henrygd/beszel-agent:0.19.0"
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

  # PERFMON: NVIDIA GPU stats via nvidia-smi
  # SYS_RAWIO / SYS_ADMIN: SMART data via smartctl
  capabilities {
    add = ["PERFMON", "SYS_RAWIO", "SYS_ADMIN"]
  }

  # NVIDIA GPU (RTX 5070) via nvidia-container-toolkit
  gpus = "all"

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
  name = "amir20/dozzle:v11.1.0"
}

resource "docker_container" "dozzle" {
  name    = "dozzle"
  image   = docker_image.dozzle.image_id
  restart = "unless-stopped"

  # No local traefik on this host — publish on loopback so the cloudflared
  # tunnel (same host) can serve it, and nothing binds to 0.0.0.0.
  ports {
    internal = 8080
    external = 8080
    ip       = "127.0.0.1"
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
}
