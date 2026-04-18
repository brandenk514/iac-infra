# IAC-INFRA

Homelab infrastructure as code. Terraform for containerized stacks over SSH; Ansible for host-level installs.

## Stacks

### Terraform

Uses the [kreuzwerker/docker](https://registry.terraform.io/providers/kreuzwerker/docker/latest) provider over SSH.

- [`terraform/main/`](terraform/main/) — primary server: Traefik, media (Sonarr/Radarr/Lidarr/Prowlarr/Jellyfin/Jellyseerr), Immich, monitoring (Beszel/Dozzle), AI (Ollama/Open WebUI), and supporting services.
- [`terraform/tdarr/`](terraform/tdarr/) — dedicated Tdarr transcode server with Intel A310 QSV hardware acceleration.

### Ansible

- [`ansible/`](ansible/) — host-level configuration for homelab Ubuntu servers. `baseline` role provisions new hosts (packages, admin user, SSH hardening, Docker, Tailscale); `update` role patches and conditionally reboots. See [ansible/README.md](ansible/README.md) for deployment flow and required variables.

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

Baseline provisioning is run by hand from a workstation (see [ansible/README.md](ansible/README.md)).

Monthly patching runs on a schedule via Gitea Actions — see [.gitea/workflows/update.yml](.gitea/workflows/update.yml). The workflow checks out the repo on a Tailnet-resident self-hosted runner, installs Ansible, writes the SSH key and inventory from repo secrets (`ANSIBLE_SSH_KEY`, `ANSIBLE_INVENTORY`), and runs `update.yml`. Fires at 04:00 UTC on the 1st of each month, and can also be triggered manually via `workflow_dispatch`.

## Layout

```
terraform/
├── main/           # primary homelab server
└── tdarr/          # dedicated transcode server
ansible/            # host-level config (baseline + update roles)
.gitea/workflows/   # scheduled monthly patching
```
