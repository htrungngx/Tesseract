# Runbook: k3s-template (`104`)

**Related ADR:** [0008](../adr/0008-vm-template-out-of-scope.md) — `104` is out of scope for Terraform.

`104` is a stopped VM template used historically as the clone source for the
4 k3s VMs (`105`–`108`). Terraform does **not** manage it. This runbook records
how it was built so it can be rebuilt if lost.

## What's on it

- **OS:** Ubuntu 22.04 Server (cloud image)
- **Sizing:** 4 GB RAM, 20 GB disk, 2 cores (when cloned)
- **Purpose:** k3s node base image

## To rebuild from scratch (if `104` is lost)

1. Download the Ubuntu 22.04 cloud image (`jammy-server-cloudimg-amd64.img`) to `pve01`.
2. Create a VM with `qm create` using the cloud image as the disk.
3. (Optional) Install any base packages you want on every k3s node (e.g.,
   `qemu-guest-agent`, curl, etc.). **Note:** this is *template-level prep,
   not in-guest app install — k3s itself is installed by you on each clone.
4. Convert to template: `qm template 104`.
5. Verify the running VMs (`105`–`108`) are unaffected — they were full
   clones with independent disks, so the template being rebuilt doesn't
   touch them.

## Why this isn't Terraform

Per ADR-0008: `104` is a historical bootstrap artifact, like the
community-scripts are for LXCs (ADR-0001). If reproducibility becomes
valuable, **Packer** is the answer — that's a separate, future ADR.
