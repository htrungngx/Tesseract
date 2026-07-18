# Tesseract

Htrung's homelab — Proxmox (`pve01`) guest fleet, managed as Infrastructure
as Code with Terraform. 9 LXCs + 4 VMs across DNS, *arr stack, media, k3s,
monitoring, and ingress.

> **Status:** IaC adoption in progress. Existing guests are imported into
> state, never recreated (ADR-0001). Currently in **Phase 1** (local-first,
> no CI) — Atlantis planned for Phase 2 (ADR-0010).

## Quick start

```sh
# 1. Copy the env template and fill in real values (see .env.example).
cp .env.example .env
$EDITOR .env

# 2. Bootstrap the two one-time things (runbooks):
#    - docs/runbooks/proxmox-bootstrap.md  (create root@pam!terraform token)
#    - docs/runbooks/r2-bootstrap.md       (create tesseract-tfstate bucket)

# 3. Source secrets and init.
set -a; . ./.env; set +a
make init

# 4. Copy tfvars and adjust (verify os_template paths with `pveam list local`).
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# 5. Import existing guests one at a time (ADR-0001).
make import-lxc NAME=adguard
# ... repeat for each guest

# 6. Review the plan, reconcile diffs by hand (first plan after import always
#    shows diffs — confirm each is cosmetic before applying).
make plan
```

## Repository layout

```
tesseract/
├── terraform/          # ALL Terraform code (ADR-0004)
│   ├── main.tf         # two module calls, one per guest kind
│   ├── modules/
│   │   ├── lxc/        # generic LXC module
│   │   └── vm/         # generic VM module (no clone — ADR-0008)
│   ├── backend.tf      # R2 state backend (ADR-0003)
│   ├── provider.tf     # bpg/proxmox (ADR-0002)
│   └── versions.tf     # pins
├── scripts/check-ips   # sentinel: detect router-side IP drift (ADR-0007)
├── docs/
│   ├── adr/            # 11 ADRs — read these before changing anything
│   ├── glossary/       # ubiquitous language
│   └── runbooks/       # manual ops procedures
├── Makefile            # operator shortcuts (make help)
├── .env.example        # env var contract (ADR-0009)
└── .gitignore
```

## ADRs (read before you change anything)

| # | Decision |
|---|---|
| 0001 | [Import existing guests — never recreate](docs/adr/0001-import-existing-guests-do-not-recreate.md) |
| 0002 | [bpg/proxmox provider + root@pam API token](docs/adr/0002-proxmox-provider-and-auth.md) |
| 0003 | [Cloudflare R2 state backend](docs/adr/0003-cloudflare-r2-state-backend.md) |
| 0004 | [Repository layout](docs/adr/0004-repository-layout.md) |
| 0005 | [Inventory as data — for_each over map](docs/adr/0005-inventory-as-data-for-each-over-map.md) |
| 0006 | [Terraform scope: shells only, no provisioners](docs/adr/0006-terraform-scope-shells-only.md) |
| 0007 | [DHCP networking, expected_ip, sentinel check](docs/adr/0007-network-mode-dhcp-expected-ip.md) |
| 0008 | [VM template 104 out of scope — standalone VMs](docs/adr/0008-vm-template-out-of-scope.md) |
| 0009 | [Secrets: Tier 1 env vars, secret-free tfvars](docs/adr/0009-secrets-handling-tier-1.md) |
| 0010 | [CI/CD deferred — local-first now, Atlantis later](docs/adr/0010-ci-cd-deferred-local-first.md) |

## Common tasks

```sh
make help           # list all commands
make plan           # plan with tfvars
make apply          # apply (Phase 1: from your laptop)
make check-ips      # sentinel — verify guests at expected_ip
make fmt            # format all .tf files
make import-lxc NAME=adguard   # import an existing LXC
make import-vm  NAME=k3s_master01   # import an existing VM
```

## What this repo does NOT do

Per the ADRs, explicitly out of scope:

- **Install software inside guests.** Done historically via community-scripts
  (ADR-0001). Future config-management tooling (Ansible, cloud-init) is
  deferred (ADR-0006).
- **Manage router DHCP.** Router has no API (ADR-0007).
- **Manage the Cloudflare tunnel token.** Lives on the `cloudflared` LXC,
  not here (ADR-0009).
- **Manage VM template `104`.** Hand-built; documented in runbook (ADR-0008).
- **Run CI.** Phase 2, Atlantis (ADR-0010).
