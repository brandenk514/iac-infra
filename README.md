# terra-infra

Terraform-managed homelab Docker infrastructure.

Uses the [kreuzwerker/docker](https://registry.terraform.io/providers/kreuzwerker/docker/latest) provider over SSH to manage containers on remote Docker hosts.

## Stacks

- [`terraform/main/`](terraform/main/) — primary server: Traefik, media (Sonarr/Radarr/Lidarr/Prowlarr/Jellyfin/Jellyseerr), Immich, monitoring (Beszel/Dozzle), AI (Ollama/Open WebUI), and supporting services.
- [`terraform/tdarr/`](terraform/tdarr/) — dedicated Tdarr transcode server with Intel A310 QSV hardware acceleration.

## Usage

Each stack is a separate Terraform root module. From inside a stack directory:

```sh
cp terraform.tfvars.example terraform.tfvars  # fill in values (when present)
terraform init
terraform plan
terraform apply
```

## Layout

```
terraform/
├── main/       # primary homelab server
└── tdarr/      # dedicated transcode server
```
