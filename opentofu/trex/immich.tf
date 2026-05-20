# ---------------------------------------------------------------------------
# Immich – Photo Management
# ---------------------------------------------------------------------------
resource "docker_image" "immich_server" {
  name = "ghcr.io/immich-app/immich-server:${var.immich_version}"
}

resource "docker_container" "immich_server" {
  name    = "immich_server"
  image   = docker_image.immich_server.image_id
  restart = "unless-stopped"

  device_requests {
    driver     = "cdi"
    device_ids = ["nvidia.com/gpu=all"]
  }

  networks_advanced {
    name = docker_network.proxy.id
  }
  networks_advanced {
    name = docker_network.immich.id
  }

  volumes {
    host_path      = var.upload_location
    container_path = "/data"
  }
  volumes {
    host_path      = "/etc/localtime"
    container_path = "/etc/localtime"
    read_only      = true
  }

  env = [
    "DB_PASSWORD=${var.db_password}",
    "DB_USERNAME=${var.db_username}",
    "DB_DATABASE_NAME=${var.db_database_name}",
    "DB_DATA_LOCATION=${var.db_data_location}",
    "UPLOAD_LOCATION=${var.upload_location}",
    "IMMICH_VERSION=${var.immich_version}",
    "DB_HOSTNAME=immich_postgres",
    "REDIS_HOSTNAME=immich_redis",
    "TZ=${var.timezone}",
  ]

  depends_on = [
    docker_container.immich_redis,
    docker_container.immich_postgres,
  ]

  dynamic "labels" {
    for_each = {
      "traefik.enable"                                               = "true"
      "traefik.docker.network"                                       = "proxy"
      "traefik.http.routers.immich-server.rule"                      = "Host(`photos.uaccloud.com`)"
      "traefik.http.services.immich-server.loadbalancer.server.port" = "2283"
      "traefik.http.routers.immich-server.tls"                       = "true"
      "traefik.http.routers.immich-server.tls.certresolver"          = "cloudflare"
      "traefik.http.routers.immich-server.entrypoints"               = "external-websecure"
    }
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# Immich Machine Learning
# ---------------------------------------------------------------------------
resource "docker_image" "immich_ml" {
  name = "ghcr.io/immich-app/immich-machine-learning:${var.immich_version}"
}

resource "docker_container" "immich_ml" {
  name    = "immich_machine_learning"
  image   = docker_image.immich_ml.image_id
  restart = "unless-stopped"

  device_requests {
    driver     = "cdi"
    device_ids = ["nvidia.com/gpu=all"]
  }

  networks_advanced {
    name = docker_network.immich.id
  }

  volumes {
    host_path      = "${var.docker_mnt}/immich-repo/model-cache"
    container_path = "/cache"
  }

  env = [
    "DB_PASSWORD=${var.db_password}",
    "DB_USERNAME=${var.db_username}",
    "DB_DATABASE_NAME=${var.db_database_name}",
    "IMMICH_VERSION=${var.immich_version}",
    "DB_HOSTNAME=immich_postgres",
    "REDIS_HOSTNAME=immich_redis",
    "TZ=${var.timezone}",
  ]
}

# ---------------------------------------------------------------------------
# Valkey – Cache for Immich (Redis-compatible)
# ---------------------------------------------------------------------------
resource "docker_image" "redis" {
  name = "docker.io/valkey/valkey:9@sha256:4963247afc4cd33c7d3b2d2816b9f7f8eeebab148d29056c2ca4d7cbc966f2d9"
}

resource "docker_container" "immich_redis" {
  name    = "immich_redis"
  image   = docker_image.redis.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.immich.id
  }

  healthcheck {
    test     = ["CMD-SHELL", "redis-cli ping || exit 1"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}

# ---------------------------------------------------------------------------
# PostgreSQL (VectorChord + pgvecto-rs) – Database for Immich
# ---------------------------------------------------------------------------
resource "docker_image" "immich_postgres" {
  name = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23"
}

resource "docker_container" "immich_postgres" {
  name     = "immich_postgres"
  image    = docker_image.immich_postgres.image_id
  restart  = "unless-stopped"
  shm_size = 128

  networks_advanced {
    name = docker_network.immich.id
  }

  env = [
    "POSTGRES_PASSWORD=${var.db_password}",
    "POSTGRES_USER=${var.db_username}",
    "POSTGRES_DB=${var.db_database_name}",
    "POSTGRES_INITDB_ARGS=--data-checksums",
  ]

  volumes {
    host_path      = var.db_data_location
    container_path = "/var/lib/postgresql/data"
  }
}
