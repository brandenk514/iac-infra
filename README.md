# IAC-INFRA

Homelab infrastructure as code. Terraform for containerized stacks over SSH; Ansible for host-level installs.

## Stacks

### Terraform

Uses the [kreuzwerker/docker](https://registry.terraform.io/providers/kreuzwerker/docker/latest) provider over SSH.

- [`terraform/main/`](terraform/main/) — primary server: Traefik, media (Sonarr/Radarr/Lidarr/Prowlarr/Jellyfin/Jellyseerr), Immich, monitoring (Beszel/Dozzle), AI (Ollama/Open WebUI), and supporting services.
- [`terraform/tdarr/`](terraform/tdarr/) — dedicated Tdarr transcode server with Intel A310 QSV hardware acceleration.

### Ansible

- [`ansible/`](ansible/) — Pterodactyl Panel + Wings on a DMZ host, fronted by a Cloudflare Tunnel. See [ansible/README.md](ansible/README.md) for deployment flow and required secrets.

## Usage

### Terraform stacks

From inside a stack directory:

```sh
cp terraform.tfvars.example terraform.tfvars  # fill in values (when present)
terraform init
terraform plan
terraform apply
```

### Ansible

Runs via Gitea Actions on push to `ansible/**`. See [.gitea/workflows/pterodactyl.yml](.gitea/workflows/pterodactyl.yml).

## Layout

```
terraform/
├── main/       # primary homelab server
└── tdarr/      # dedicated transcode server
ansible/        # pterodactyl DMZ host
```
