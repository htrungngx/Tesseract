# ADR 0011: LXC templates are managed by Terraform

- **Status:** Accepted
- **Date:** 2026-07-18

## Context

Adding a new LXC used to require SSH to `pve01` and running
`pveam download local <template>` before `terraform apply` could reference it.
This couples IaC to a manual step on the host and breaks the "add a guest is
a data-only change" property from ADR-0005.

`bpg/proxmox` exposes `proxmox_virtual_environment_download_file`, which calls
Proxmox's `download-url` API to fetch a template (or ISO) directly into a
datastore. Declaring templates as Terraform resources removes the SSH step
entirely — `terraform apply` pulls them.

## Decision

Manage LXC templates as Terraform resources via a `templates` map in tfvars:

```hcl
templates = {
  debian-13 = {
    url                  = "https://.../debian-13-standard_13.1-2_amd64.tar.zst"
    checksum             = "..."
    checksum_algorithm   = "sha256"
  }
  # ...
}
```

Root `main.tf` instantiates one `proxmox_virtual_environment_download_file`
per entry via `for_each`. The `os_template` path string in each LXC tfvars
entry (e.g. `local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst`) must match
the filename the download produces. They are deliberately decoupled (no
computed reference) so existing imported LXCs keep working without code change.

## Consequences

- **Adding a guest whose template isn't on pve01** = add the template to the
  `templates` map and run `terraform apply` once before adding the guest.
  No SSH, no `pveam`.
- **Existing templates were imported** (one-time, see `runbooks/add-guest.md`).
  After import they're managed by Terraform like any other resource.
- **Removing a template from the map deletes it from pve01 storage.** Every
  download resource has `prevent_destroy` to make this a deliberate code
  change, not an accident.
- **Module-managed applies are slightly slower** — Terraform checks file size
  on every plan. Negligible at this scale (3 templates, KB metadata).
- **Resource rename pending.** `proxmox_virtual_environment_download_file` →
  `proxmox_download_file` in provider v1.0. When we upgrade past 0.111, a
  one-shot `terraform state mv` per template is the migration.
- **Does not apply to VM images.** VMs use cloud images / clone from template
  `104`, which is out of scope (ADR-0008). This ADR is LXC-only.

## Privileges

`proxmox_virtual_environment_download_file` requires `Datastore.AllocateTemplate`,
`Sys.Audit`, and `Sys.Modify`. The `root@pam!terraform` token (ADR-0002) has
all three via root.
