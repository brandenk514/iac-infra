# ---------------------------------------------------------------------------
# Ollama – Local LLM Runtime
# ---------------------------------------------------------------------------
resource "docker_image" "ollama" {
  name = "ollama/ollama:latest"
}

resource "docker_container" "ollama" {
  name    = "ollama"
  image   = docker_image.ollama.image_id
  restart = "unless-stopped"
  gpus    = "1"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["ollama"]
  }

  volumes {
    host_path      = "${var.docker_mnt}/ollama"
    container_path = "/root/.ollama"
  }

  env = [
    "OLLAMA_HOST=0.0.0.0:11434",
    "TZ=${var.timezone}",
  ]

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                      = "true"
      "traefik.http.routers.ollama.rule"                    = "Host(`ollama.local.uaccloud.com`)"
      "traefik.http.services.ollama.loadbalancer.server.port" = "11434"
      "traefik.http.routers.ollama.tls"                     = "true"
      "traefik.http.routers.ollama.tls.certresolver"        = "cloudflare"
      "traefik.http.routers.ollama.entrypoints"             = "websecure"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# Open WebUI – Chat Frontend for Ollama
# ---------------------------------------------------------------------------
resource "docker_image" "openwebui" {
  name = "ghcr.io/open-webui/open-webui:latest"
}

resource "docker_container" "openwebui" {
  name    = "openwebui"
  image   = docker_image.openwebui.image_id
  restart = "unless-stopped"
  gpus    = "1"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["openwebui"]
  }

  volumes {
    host_path      = "${var.docker_mnt}/openwebui"
    container_path = "/app/backend/data"
  }

  env = [
    "OLLAMA_BASE_URL=http://ollama:11434",
    "OLLAMA_API_BASE_URL=http://ollama:11434/api",
    "WEBUI_SECRET_KEY=${var.webui_secret_key}",
    "TZ=${var.timezone}",
  ]

  depends_on = [
    docker_container.ollama,
  ]

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                         = "true"
      "traefik.http.routers.openwebui.rule"                    = "Host(`ai.local.uaccloud.com`)"
      "traefik.http.services.openwebui.loadbalancer.server.port" = "8080"
      "traefik.http.routers.openwebui.tls"                     = "true"
      "traefik.http.routers.openwebui.tls.certresolver"        = "cloudflare"
      "traefik.http.routers.openwebui.entrypoints"             = "websecure"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}
