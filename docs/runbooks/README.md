# Runbooks

Operational procedures — things that are deliberately manual (per the ADRs)
but should not live in someone's head. Each is a short checklist.

## Index

- [`add-guest.md`](./add-guest.md) — Add a new LXC or VM (data-only change to tfvars).
- [`k3s-template.md`](./k3s-template.md) — How VM template `104` was built and how to rebuild it.
- [`router-ops.md`](./router-ops.md) — 4G router admin: DHCP, reboots, when to run `make check-ips`.
- [`state-recovery.md`](./state-recovery.md) — Rolling back Terraform state on R2.
- [`proxmox-bootstrap.md`](./proxmox-bootstrap.md) — One-time Proxmox API token creation.
- [`r2-bootstrap.md`](./r2-bootstrap.md) — One-time R2 bucket creation for state.
