# AGENTS.md — Infrastructure & Configuration Pipeline

## 1. Project Architecture
This repository uses a two-phase architecture where OpenTofu provisions the underlying infrastructure, outputs connection details, and Ansible takes over to configure the software layer.

The directory structure is maintained as follows:
```text
.
├── ansible/
│   ├── ansible.cfg
│   ├── group_vars/
│   │   └── main.yml
│   |── site.yml
|   |__ requirements.yml
│   └── roles/
└── opentofu/
    ├── nanosaurus/
    │    ├── main.tf
    │    ├── outputs.tf
    │    ├── variables.tf
    │    └── terraform.tfvars
    |__ trex/
    │    ├── main.tf
    │    ├── outputs.tf
    │    ├── variables.tf
    │    └── terraform.tfvars
    |__ pterodactyl/
    │    ├── main.tf
    │    ├── outputs.tf
    │    ├── variables.tf
    │    └── terraform.tfvars
    └── modules/
```

## 2. OpenTofu Coding Guidelines
- **State Management:** Always use remote state (e.g., S3, OpenTofu Cloud). Never commit `.tfstate`, `.tfvars`, or `.tfstate.backup` files to Git.
- **Variables & Outputs:** Ensure every resource tag includes `ManagedBy = "OpenTofu+Ansible"`. Define outputs for all connection data (e.g., `public_ip`, `instance_id`) so Ansible can dynamically consume them.
- **Modules:** Favor composition over repetition. Extract reusable infrastructure pieces into `opentofu/modules/`.
- **Formatting:** Enforce formatting consistency on all `.tf` files using the command: `tofu fmt -recursive`.

## 3. Ansible Coding Guidelines
- **Agentless Execution:** Ensure all playbooks are designed to run over SSH or WinRM. No target node agents are allowed.
- **Idempotency:** Every task must be fully idempotent. Use modules like `template`, `copy`, and `service` rather than generic `shell` or `command` modules whenever possible.
- **FQCNs:** Use Fully Qualified Collection Names (FQCN) for all modules (e.g., use `ansible.builtin.copy` instead of `copy`).
- **Variables:** Keep Jinja2 templating simple and avoid duplicating logic. Store shared variables at the `group_vars` or `host_vars` level.

## 4. Pipeline & Integration Rules
- **Sequential Execution:** The pipeline must enforce OpenTofu execution followed immediately by Ansible. 
- **Dynamic Inventory:** When generating your Ansible inventory, use OpenTofu output parsing (e.g., `tofu output -json`) or the `tofu_inventory` plugin to keep hosts up to date.
- **Sensitive Data:** Never hardcode secrets. All sensitive OpenTofu variables and Ansible vault files must be encrypted or managed via an external secrets manager.

## 5. Testing & CI/CD Workflow
Before opening a pull request or merging changes, the following checks must be completed:
1. Run `tofu validate` and `tofu plan` to ensure infrastructure syntax is correct.
2. Ensure no breaking changes are introduced to the existing OpenTofu state.
3. Run `ansible-lint playbooks/site.yml` to verify playbook syntax and best practices.
4. If modifying roles, run `molecule test` locally to validate role behavior.

## 6. Pull Request Instructions
- **Branch Naming:** Use `feature/`, `bugfix/`, or `hotfix/` prefixes.
- **Commit Messages:** Use conventional commit formats (e.g., `feat(network): provision AWS VPC`, `fix(nginx): restart service on config change`).
- **Single Commit:** Ensure the PR resolves a single, specific issue or task without mixing unrelated changes.
