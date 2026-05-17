---
description: Rule to help understand folder structure for opentofu and ansible project architecture.
---

# Project Architecture
This is a opentofu and ansible project architecture that follows best practices for organizing code and resources. The structure is designed to promote modularity, maintainability, and scalability.

- opentofu code is organized in the `opentofu` directory, with separate subdirectories for different environments (e.g. `trex`, `nanosarus`, and `pterodactyl`). Each host has a different function based on the container on the host.
- Ansible playbooks and roles are organized in the `ansible` directory, where configurations are standardized and reusable across different environments.

## Coding Standards
- opentofu code should follow the [opentofu Style Guide](https://opentofu.org/docs/language/syntax/style.html) to ensure consistency and readability.
- Ansible playbooks should follow the [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html) to ensure maintainability and scalability.

### Repository Access

You can use the `gh` CLI to:

- Search for issues: `gh issue list --repo owner/repo`
- View pull requests: `gh pr list --repo owner/repo`
- Clone repositories: `gh repo clone owner/repo`
