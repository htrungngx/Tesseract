# ADR 0002: Use the bpg/proxmox Terraform provider with root@pam API token

- **Status:** Accepted
- **Date:** 2026-07-17

## Context

Terraform needs a Proxmox VE provider to manage guests (LXCs and VMs) on
`pve01`. The two options historically available were:

- **`Telmate/proxmox`** — the original community provider. Effectively
  unmaintained; the community has moved off it.
- **`bpg/proxmox`** — the actively maintained successor. Weekly-ish releases,
  full coverage of `pve` resources, registry docs at
  <https://registry.terraform.io/providers/bpg/proxmox>, source at
  <https://github.com/bpg/terraform-provider-proxmox>.

There is no first-party Proxmox provider.

Separately, the provider must authenticate to the Proxmox API at
`https://192.168.1.21:8006/api2/json`. Three realistic patterns:

1. **API token on `root@pam`.** One user, one separately revocable token.
2. **Dedicated `terraform@pve` user with its own token.** More isolated, more
   setup (user, ACLs, realm).
3. **Password-based** (`root@pam` password in env). Avoids token rotation but
   puts a powerful password into the runtime environment.

## Decision

Adopt **`bpg/proxmox`**, pinned to `~> 0.111` (latest patch of the 0.111 line,
allowing bugfixes without surprise schema migrations on a live homelab).

Use these resource types:
- `proxmox_virtual_environment_vm` for VMs — *not* the legacy `vm_qemu` alias,
  which is on the deprecation path.
- `proxmox_virtual_environment_container` for LXCs.

For authentication: **API token on `root@pam`**, named `terraform`.
Token ID `root@pam!terraform`; the bpg provider combines token ID + secret into
a **single environment variable** `PROXMOX_VE_API_TOKEN` in the form
`root@pam!terraform=<secret>`. The endpoint is set via `PROXMOX_VE_ENDPOINT`.
Both are consumed via the provider's standard env-var interface — **never
committed to the repo**.

(Note: an earlier draft of this ADR referenced `PM_API_TOKEN_ID` /
`PM_API_TOKEN_SECRET`. Those are the **Telmate** provider's env var names and
do not exist in `bpg/proxmox`. The bpg prefix is `PROXMOX_VE_*`.)

OpenTofu compatibility note: `bpg/proxmox` works identically on Terraform and
OpenTofu. This repo uses the Terraform binary; switching to OpenTofu later is a
toolchain-only change, no HCL rewrite.

## Consequences

- One provider to learn, one set of resource schemas, one upgrade path.
- `vm_qemu` is explicitly avoided; anyone adding a VM uses `proxmox_virtual_environment_vm`.
- The `terraform` token can be revoked independently of the `root@pam` password
  if it leaks. The token has root-equivalent privileges; we rely on the token
  secret + the host environment for protection (see ADR on secrets).
- Future bpg 0.x → 1.0 (or any breaking minor) will require a deliberate
  upgrade pass with a `terraform plan` review — pinned to a major line so this
  is opt-in, not accidental.
- Future, more-locked-down setups (e.g., separate `terraform@pve` user, RBAC
  via ACLs) are additive: create the user, reissue the token, update env vars.
  No code change required.

## References

- Provider registry: <https://registry.terraform.io/providers/bpg/proxmox/latest>
- Provider source: <https://github.com/bpg/terraform-provider-proxmox>
- `vm` resource docs: <https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm>
- `container` resource docs: <https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_container>
