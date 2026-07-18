# ADR 0004: Repository layout — `terraform/` subdir, generic modules, docs/CI siblings

- **Status:** Accepted
- **Date:** 2026-07-17
- **Supersedes:** nothing
- **Amended by:** ADR-0006 (removed the `ansible/` sibling from the initial layout)

## Context

The repo must house distinct concerns with different lifecycles and tooling:
Terraform (Proxmox guest provisioning) and operational artifacts (docs, CI).
A flat layout mixes these; a deeply nested one over-engineers a single-host
homelab.

We also stated a hard rule: **everything Terraform-related lives under
`terraform/`**, not at the repo root. This keeps the repo root a navigation
index, not a junk drawer.

## Decision

Adopt the following top-level layout:

```
tesseract/
├── terraform/                  # ALL Terraform code lives here
│   ├── main.tf                 # entry: provider config + module calls
│   ├── versions.tf             # required_version + required_providers pins
│   ├── backend.tf              # the s3 (R2) backend block
│   ├── variables.tf            # input schema (the inventory shape)
│   ├── outputs.tf
│   ├── terraform.tfvars        # real values — GITIGNORED
│   ├── terraform.tfvars.example  # template committed to repo
│   └── modules/
│       ├── lxc/                # generic LXC module
│       └── vm/                 # generic VM module (clone-from-template)
├── docs/                       # ADRs, glossary, runbooks
│   ├── adr/
│   └── glossary/
└── .github/workflows/          # CI (see ADR on CI/CD)
```

### Module count: exactly two, both generic

- `modules/lxc/` — one `proxmox_virtual_environment_container` resource +
  input variables for everything that varies per guest. No family-specific
  modules (`*arr`, `infra`, `k3s_node`) — those are **data differences** in
  tfvars, not code differences. We explicitly do *not* model guest families.
- `modules/vm/` — one `proxmox_virtual_environment_vm` resource, cloning from
  a template ID (k3s-template `104`) + input variables. Same shape as `lxc/`.

### The repo root is an index, not a working directory

Every `terraform` command runs from `terraform/` (i.e. `cd terraform && terraform plan`).
CI workflows must set `working-directory: terraform` (or `defaults.run`).
This is a deliberate cost of the `terraform/` subdir choice — paid once per
workflow, worth it for the clean root.

### No `ansible/` sibling (for now)

ADR-0006 defers the choice of in-guest configuration tool. Ansible is **not**
part of the initial layout. If a config-management tool is later adopted, it
lands at `ansible/` (or equivalent) as a sibling to `terraform/`. The layout
above leaves room for it; we just don't add an empty directory.

## Consequences

- Adding a new guest of an existing kind = editing tfvars only. No new `.tf`
  file. (See ADR-0005 for the inventory pattern.)
- Adding a new *kind* of guest (e.g., a future VM that doesn't clone from
  `k3s-template`) = a new module under `modules/`. Rare; explicit.
- All Terraform state, lock files, and `.terraform/` stay scoped to
  `terraform/.terraform/` — one `.gitignore` rule, no root pollution.
- CI must `cd terraform` (or equivalent) before invoking the toolchain.
- The two modules are deliberately tiny. Resist the urge to add a third module
  for "families" — that way lies premature abstraction. Family differences are
  data, not code.
