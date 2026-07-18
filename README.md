# Tesseract

Homelab Proxmox fleet as IaC. 9 LXCs + 4 VMs on `pve01`.

Existing guests are imported into state, never recreated. See `docs/adr/` for
the decisions behind every choice. Phase 1 (local laptop, no CI) — Atlantis
deferred.

## Quick start

```sh
cp .env.example .env && $EDITOR .env        # Proxmox token + R2 keys
set -a; . ./.env; set +a
make init
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
make import-lxc NAME=adguard                # repeat per guest
make plan                                   # review diffs before applying
```

Bootstrap runbooks (one-time): `docs/runbooks/proxmox-bootstrap.md`,
`docs/runbooks/r2-bootstrap.md`.

## Layout

```
terraform/           # main.tf, variables.tf, outputs.tf, tfvars.example
terraform/modules/{lxc,vm}/
scripts/check-ips    # drift sentinel
docs/{adr,glossary,runbooks}/
Makefile
.env.example
```

## Common tasks

```sh
make plan
make apply
make check-ips
make fmt
make validate
make import-lxc NAME=adguard
make import-vm  NAME=k3s-master01
```

## Out of scope

In-guest software (community-scripts did it historically). Router DHCP (no
API). Cloudflare tunnel token (lives on the `cloudflared` LXC). VM template
`104` (hand-built; see runbook).
