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

  device_requests {
    driver     = "cdi"
    device_ids = ["nvidia.com/gpu=all"]
  }

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
    "OLLAMA_CONTEXT_LENGTH=131071",
    "TZ=${var.timezone}",
  ]

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                        = "true"
      "traefik.http.routers.ollama.rule"                      = "Host(`ollama.local.uaccloud.com`)"
      "traefik.http.services.ollama.loadbalancer.server.port" = "11434"
      "traefik.http.routers.ollama.tls"                       = "true"
      "traefik.http.routers.ollama.tls.certresolver"          = "cloudflare"
      "traefik.http.routers.ollama.entrypoints"               = "websecure"
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

  ulimit {
    name = "nofile"
    soft = 65536
    hard = 65536
  }

  device_requests {
    driver     = "cdi"
    device_ids = ["nvidia.com/gpu=all"]
  }

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["openwebui"]
  }

  volumes {
    host_path      = "${var.docker_mnt}/openwebui"
    container_path = "/app/backend/data"
  }

  env = [
    "DATA_DIR=/app/backend/data",
    "OLLAMA_BASE_URL=http://ollama:11434",
    "OLLAMA_API_BASE_URL=http://ollama:11434/api",
    "WEBUI_SECRET_KEY=${var.webui_secret_key}",
    "ENABLE_RAG_HYBRID_SEARCH=true",
    "RAG_RERANKING_ENGINE=external",
    "RAG_EXTERNAL_RERANKER_URL=http://infinity:7997/rerank",
    "RAG_RERANKING_MODEL=BAAI/bge-reranker-v2-m3",
    "RAG_TOP_K=20",
    "RAG_TOP_K_RERANKER=5",
    "RAG_SYSTEM_CONTEXT=true",
    "ENABLE_RAG_WEB_SEARCH=true",
    "ENABLE_WEB_SEARCH=true",
    "RAG_WEB_SEARCH_ENGINE=searxng",
    "WEB_SEARCH_ENGINE=searxng",
    "SEARXNG_QUERY_URL=http://searxng:8080/search?q=<query>",
    "TZ=${var.timezone}",
  ]

  depends_on = [
    docker_container.ollama,
    docker_container.infinity,
    docker_container.searxng,
  ]

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                           = "true"
      "traefik.http.routers.openwebui.rule"                      = "Host(`ai.local.uaccloud.com`)"
      "traefik.http.services.openwebui.loadbalancer.server.port" = "8080"
      "traefik.http.routers.openwebui.tls"                       = "true"
      "traefik.http.routers.openwebui.tls.certresolver"          = "cloudflare"
      "traefik.http.routers.openwebui.entrypoints"               = "websecure"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# Apache Tika – Document Text Extraction (RAG ingest)
# ---------------------------------------------------------------------------
resource "docker_image" "tika" {
  name = "apache/tika:latest-full"
}

resource "docker_container" "tika" {
  name    = "tika"
  image   = docker_image.tika.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["tika"]
  }

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                      = "true"
      "traefik.http.routers.tika.rule"                      = "Host(`tika.local.uaccloud.com`)"
      "traefik.http.services.tika.loadbalancer.server.port" = "9998"
      "traefik.http.routers.tika.tls"                       = "true"
      "traefik.http.routers.tika.tls.certresolver"          = "cloudflare"
      "traefik.http.routers.tika.entrypoints"               = "websecure"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# SearXNG – Privacy-respecting Metasearch (used by Open WebUI web search)
# ---------------------------------------------------------------------------
resource "docker_image" "searxng_redis" {
  name = "redis:alpine"
}

resource "docker_container" "searxng_redis" {
  name    = "searxng-redis"
  image   = docker_image.searxng_redis.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["searxng-redis"]
  }

  volumes {
    host_path      = "${var.docker_mnt}/searxng/redis"
    container_path = "/data"
  }
}

resource "docker_image" "searxng" {
  name = "searxng/searxng:latest"
}

resource "docker_container" "searxng" {
  name    = "searxng"
  image   = docker_image.searxng.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["searxng"]
  }

  volumes {
    host_path      = "${var.docker_mnt}/searxng/config"
    container_path = "/etc/searxng"
  }
  volumes {
    host_path      = "${var.docker_mnt}/searxng/cache"
    container_path = "/var/cache/searxng"
  }

  env = [
    "SEARXNG_BASE_URL=https://search.local.uaccloud.com/",
    "SEARXNG_REDIS_HOST=searxng-redis",
    "SEARXNG_REDIS_PORT=6379",
    "UWSGI_WORKERS=4",
    "UWSGI_THREADS=4",
    "TZ=${var.timezone}",
  ]

  depends_on = [
    docker_container.searxng_redis,
  ]

  log_driver = "json-file"
  log_opts = {
    "max-size" = "1m"
    "max-file" = "1"
  }

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                         = "true"
      "traefik.http.routers.searxng.rule"                      = "Host(`search.local.uaccloud.com`)"
      "traefik.http.services.searxng.loadbalancer.server.port" = "8080"
      "traefik.http.routers.searxng.tls"                       = "true"
      "traefik.http.routers.searxng.tls.certresolver"          = "cloudflare"
      "traefik.http.routers.searxng.entrypoints"               = "websecure"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# Open Terminal – Sandboxed Shell for Open WebUI tools
# ---------------------------------------------------------------------------
resource "docker_image" "open_terminal" {
  name = "ghcr.io/open-webui/open-terminal:latest"
}

resource "docker_container" "open_terminal" {
  name    = "open-terminal"
  image   = docker_image.open_terminal.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["open-terminal"]
  }

  volumes {
    host_path      = "${var.docker_mnt}/open-terminal/home"
    container_path = "/home/user"
  }

  env = [
    "OPEN_TERMINAL_API_KEY=${var.open_terminal_api_key}",
    "OPEN_TERMINAL_PACKAGES=ripgrep tree cron curl",
    "OPEN_TERMINAL_PIP_PACKAGES=httpx polars",
    "OPEN_TERMINAL_MULTI_USER=true",
    "TZ=${var.timezone}",
  ]

  security_opts = ["no-new-privileges:false"]

  capabilities {
    drop = ["NET_ADMIN", "SYS_ADMIN"]
  }

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                               = "true"
      "traefik.http.routers.open-terminal.rule"                      = "Host(`terminal.local.uaccloud.com`)"
      "traefik.http.services.open-terminal.loadbalancer.server.port" = "8000"
      "traefik.http.routers.open-terminal.tls"                       = "true"
      "traefik.http.routers.open-terminal.tls.certresolver"          = "cloudflare"
      "traefik.http.routers.open-terminal.entrypoints"               = "websecure"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# Infinity – Reranker for Open WebUI hybrid RAG
# ---------------------------------------------------------------------------
resource "docker_image" "infinity" {
  name = "michaelf34/infinity:0.0.77"
}

resource "docker_container" "infinity" {
  name    = "infinity"
  image   = docker_image.infinity.image_id
  restart = "unless-stopped"

  device_requests {
    driver     = "cdi"
    device_ids = ["nvidia.com/gpu=all"]
  }

  networks_advanced {
    name    = docker_network.proxy.id
    aliases = ["infinity"]
  }

  volumes {
    host_path      = "${var.docker_mnt}/infinity/cache"
    container_path = "/app/.cache"
  }

  command = [
    "v2",
    "--model-id", "BAAI/bge-reranker-v2-m3",
    "--engine", "torch",
    "--device", "cuda",
    "--batch-size", "32",
    "--port", "7997",
    "--no-bettertransformer",
  ]

  healthcheck {
    test         = ["CMD", "curl", "-f", "http://localhost:7997/health"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "120s"
  }

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                          = "true"
      "traefik.http.routers.infinity.rule"                      = "Host(`infinity.local.uaccloud.com`)"
      "traefik.http.services.infinity.loadbalancer.server.port" = "7997"
      "traefik.http.routers.infinity.tls"                       = "true"
      "traefik.http.routers.infinity.tls.certresolver"          = "cloudflare"
      "traefik.http.routers.infinity.entrypoints"               = "websecure"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}
