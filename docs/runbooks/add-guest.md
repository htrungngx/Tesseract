# Runbook: Add a guest

Adding a guest is a **data-only change** — no `.tf` file touched. Edit tfvars,
plan, apply. The map key becomes both the Proxmox guest name and Terraform's
state identity; choose deliberately, don't rename later.

## Pick an ID and IP

- **vmid**: 100–113 are taken. Next free: 114, or anything in 200–999.
- **expected_ip**: observed from router DHCP. Boot a test guest first, read
  the IP it got, record it. Or pick the next free in `192.168.1.x`.

## Adding an LXC

Module defaults are already baked in (unprivileged, nesting, keyctl, fuse,
protection, DHCP, DNS, datastore, bridge). Only per-guest differences go in
tfvars:

```hcl
lxcs = {
  foo = {
    vmid         = 114
    expected_ip  = "192.168.1.138"
    description  = "What this LXC does"
    os_template  = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
    os_type      = "debian"
    cores        = 1
    memory_mb    = 1024
    disk_gb      = 4
    tags         = ["whatever"]
  }
}
```

**If the template isn't on pve01 yet:** add it to the `templates` map (ADR-0011)
and run `terraform apply` once before adding the guest. No SSH to pve01 needed.

```hcl
templates = {
  debian-13 = {
    url       = "http://download.proxmox.com/images/system/debian-13-standard_13.1-2_amd64.tar.zst"
    file_name = "debian-13-standard_13.1-2_amd64.tar.zst"
  }
}
```

The `file_name` must match the `os_template` path segment the LXC uses.

### Optional: device passthrough (e.g. GPU for transcoding)

```hcl
device_passthroughs = [
  { path = "/dev/dri/renderD128", gid = 993, mode = "0660" },
]
```

## Adding a VM

```hcl
vms = {
  "bar-vm" = {
    vmid         = 115
    expected_ip  = "192.168.1.139"
    description  = "What this VM does"
    cores        = 2
    memory_mb    = 4096
    disk_gb      = 20
    tags         = ["vm"]
  }
}
```

**Map keys must use hyphens, not underscores** — Proxmox enforces DNS naming on
`.name`, and the map key goes straight to it. Use `bar-vm`, not `bar_vm`.

### ⚠️ Known gap: brand-new VMs need a base image

The VM module has no `clone` block (ADR-0008) — VMs are modeled standalone.
A brand-new VM `apply` creates an **empty** disk with no OS; the existing 4
VMs work because they were imported, not created. To add a *bootable* new VM:

- **Import an already-running VM** (like the existing 4), or
- **Extend the VM module with a `clone` block** sourced from template `104`
  (small new feature; revisit ADR-0008 when forced).

This gap does **not** affect LXCs — `os_template` fully specifies the bootable
rootfs, so brand-new LXCs work end-to-end.

## Apply

```sh
make plan       # "1 to add, 0 to change, 0 to destroy"
make apply
```

If `make plan` shows any `-/+` (forces replacement) or destroy, **stop** and
read the diff. New guests should be pure additions.
