# ---------------------------------------------------------------------------
# Beszel Agent – Monitoring Agent (Intel GPU)
# Reports to the central Beszel hub running in the main stack.
# ---------------------------------------------------------------------------
# The -intel variant bundles igt-gpu-tools (intel_gpu_top) for Intel GPU
# metrics, plus smartmontools (smartctl) + zfs. The default scratch image
# ships none of these, so GPU usage and SMART disk-health data would never be
# collected. The agent finds intel_gpu_top / smartctl via exec.LookPath on the
# container PATH. Note: this image is amd64-only.
resource "docker_image" "beszel_agent" {
  name = "henrygd/beszel-agent-intel:0.21.0"
}

resource "docker_container" "beszel_agent" {
  name          = "beszel-agent"
  image         = docker_image.beszel_agent.image_id
  restart       = "unless-stopped"
  network_mode  = "host"
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

  # Expose the host's /mnt/r5-dstor (backed by /dev/sda1) to the agent. The
  # agent runs in a container and can't see host mounts otherwise, so sda would
  # never appear in Beszel. Mounting it under /extra-filesystems lets the agent
  # auto-discover it. The folder name follows Beszel's device__customname
  # convention: "sda1" is the device and "sda" is the custom display name. The
  # bind mount shows up in the container's mountinfo as /dev/sda1, so the agent
  # registers it with I/O key "sda1" (an exact /proc/diskstats match) and
  # display name "sda".
  volumes {
    host_path      = "/mnt/r5-dstor"
    container_path = "/extra-filesystems/sda1__sda"
    read_only      = true
  }

  env = [
    "LISTEN=45876",
    "HUB_URL=${var.beszel_agent_hub_url}",
    "TOKEN=${var.beszel_agent_token}",
    "KEY=${var.beszel_agent_key}",
  ]

  # SYS_RAWIO / SYS_ADMIN: SMART data via smartctl
  # PERFMON: intel_gpu_top reads the Intel GPU's performance counters
  # (perf_event_open) to report usage / power draw.
  capabilities {
    add = ["SYS_RAWIO", "SYS_ADMIN", "PERFMON"]
  }

  devices {
    host_path      = "/dev/nvme0n1"
    container_path = "/dev/nvme0n1"
  }
  devices {
    host_path      = "/dev/sda1"
    container_path = "/dev/sda1"
  }
  # Intel GPU: expose the DRM render nodes so intel_gpu_top can attach.
  devices {
    host_path      = "/dev/dri"
    container_path = "/dev/dri"
  }
}

# ---------------------------------------------------------------------------
# Dozzle – Container Log Viewer
# ---------------------------------------------------------------------------
resource "docker_image" "dozzle" {
  name = "amir20/dozzle:v11.3.1"
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
