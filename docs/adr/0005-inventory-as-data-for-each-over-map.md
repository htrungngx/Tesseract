# ADR 0005: Inventory as data — `for_each` over a map, defaults live in modules

- **Status:** Accepted
- **Date:** 2026-07-17

## Context

The repo's stated non-functional rule is *DRY and easy to expand*: changing a
value should happen in **one place**, not in every resource block. The homelab
has 14 guests (9 LXCs, 5 VMs) and we want adding guest #114 to be a one-line
data edit, not a copy-paste of a resource block.

Terraform offers two ways to model a fleet of similar resources:

1. **One resource block per guest** (`resource "x" "adguard" { ... }`,
   `resource "x" "hermesagent" { ... }`, …). 14 blocks, each copy-pasted and
   individually edited. Adding a guest = new block. Every shared value (e.g.,
   `onboot = true`) is repeated N times.
2. **`for_each` over a map** — one `module` (or `resource`) block, parameterized
   by a map of per-guest inputs. Adding a guest = one map entry. Shared values
   live either in the map (if they vary) or in module defaults (if they don't).

We adopt (2).

## Decision

### The inventory is data, in tfvars

All guests are described in `terraform/terraform.tfvars` as two top-level maps:
`lxcs` and `vms`. Each map value is an object with the per-guest inputs. The
key is a stable, human-readable name (e.g., `adguard`, `k3s_master01`), **not**
the numeric Proxmox ID — names are how we refer to guests in code and
conversation; the ID is just one field.

```hcl
# terraform.tfvars (sketch — real schema lives in variables.tf)
lxcs = {
  adguard      = { id = 101, ip = "192.168.1.125", os = "alpine-3.24",  cpu = 1, ram = 512,  disk = 2,  tags = ["dns","protected"] }
  hermesagent  = { id = 102, ip = "192.168.1.126", os = "debian-13",    cpu = 2, ram = 4096, disk = 20, tags = ["agent"] }
  cloudflared  = { id = 100, ip = "192.168.1.123", os = "debian-13",    cpu = 1, ram = 512,  disk = 2,  tags = ["ingress"] }
  # ... etc, one line per LXC
}

vms = {
  k3s_master01 = { id = 105, ip = "192.168.1.129", template_id = 104, cpu = 2, ram = 4096, disk = 20, role = "control-plane" }
  k3s_worker01 = { id = 106, ip = "192.168.1.130", template_id = 104, cpu = 2, ram = 4096, disk = 20, role = "worker" }
  # ... etc
}
```

### `for_each` instantiates modules from the map

In `terraform/main.tf`, each generic module is instantiated once with `for_each`
over its map:

```hcl
module "lxcs" {
  source   = "./modules/lxc"
  for_each = var.lxcs

  name   = each.key
  config = each.value
}

module "vms" {
  source   = "./modules/vm"
  for_each = var.vms

  name   = each.key
  config = each.value
}
```

### Defaults live in the modules, not in tfvars

Values that are **the same for every LXC** (unprivileged, `nesting = true`,
`keyctl = true`, `onboot = true`, DHCP networking, etc.) are declared as
module variable defaults in `modules/lxc/variables.tf` and are **never
repeated in tfvars**. tfvars carries only per-guest differences.

This is what makes "change in one place" actually true:

- *Change a per-guest value* → edit one line in tfvars.
- *Change a fleet-wide default* → edit one line in `modules/*/variables.tf`.
- *Add a guest* → add one line in tfvars.
- *Add a new knob* → add one variable to the module (with default), optionally
  override per-guest in tfvars.

### Map keys are stable identifiers

The map key (`adguard`, `k3s_master01`) is the resource's identity for
Terraform's state. Renaming a key = destroy + recreate. Choose names
deliberately and don't churn them. The numeric Proxmox ID (`vmid`) is just a
field inside the value, used by `terraform import` and by Proxmox itself.

## Consequences

- **Adding/renaming guests is a tfvars edit**, reviewed in PRs like any code
  change. CI runs `terraform plan` on the PR (see CI ADR).
- **No 14× resource-block duplication.** Diff noise when touching a shared
  default is one line, not 14.
- **All guests of a kind share identical shape** by construction. Per-guest
  deviations are explicit (a field present in that map entry) rather than
  implicit (a block where someone forgot to set `onboot`).
- **Map keys are load-bearing.** Don't rename them casually; a rename is a
  destroy/recreate of that guest in state. The Proxmox `vmid` field, by
  contrast, can change with a `terraform state mv` if ever needed.
- **tfvars is gitignored; `.example` is committed** (see secrets ADR). Real
  values live in tfvars locally and in CI secrets; the committed example
  documents the schema without exposing the homelab.
- **The `tags` field is free-form data for now.** It exists so we can later
  slice the inventory (e.g., "all `dns`-tagged guests") without restructuring.
  We do *not* build family modules around tags.
