# Runbooks

Operational procedures — things that are deliberately manual (per the ADRs)
but should not live in someone's head. Each is a short checklist.

## Index

- [`k3s-template.md`](./k3s-template.md) — How VM template `104` was built and how to rebuild it. (ADR-0008)
- [`router-ops.md`](./router-ops.md) — 4G router admin: DHCP, reboots, when to run `make check-ips`. (ADR-0007)
- [`state-recovery.md`](./state-recovery.md) — Rolling back Terraform state on R2. (ADR-0003)
- [`proxmox-bootstrap.md`](./proxmox-bootstrap.md) — One-time Proxmox API token creation. (ADR-0002)
- [`r2-bootstrap.md`](./r2-bootstrap.md) — One-time R2 bucket creation for state. (ADR-0003)
