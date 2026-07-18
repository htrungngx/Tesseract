# Glossary

Ubiquitous language for the Tesseract homelab. If a term shows up in code, a
commit message, a doc, or a conversation and could be ambiguous, define it here.

## Terms

### pve01
The Proxmox VE host. GMK NUC N150, 16 GB RAM, 476.9 GB NVMe (`local-lvm` thin pool).
Bridged on `vmbr0` at `192.168.1.21`.

### LXC
Linux Container, unprivileged, Proxmox-managed. In Tesseract these are guests
with integer IDs `100`–`113` (see inventory).

### VM (k3s nodes)
Fully virtualized guests (`104`–`108`) used for the Kubernetes/k3s cluster.
`104` is a clone template; `105`–`108` are running cluster nodes.

### Thin pool (`local-lvm`)
The LVM-thin storage pool on the Proxmox NVMe that backs all guest disks.
~348.8 GB total, ~25% used at time of IaC adoption.

### Guest
Collective term for any LXC or VM running under Proxmox on pve01.

### IaC
Infrastructure as Code — declarative configuration of the Proxmox guests and
their provisioning pipeline. In Tesseract, this is the contents of this repo.

### hermes
The unprivileged admin user created inside each guest by the Ansible
bootstrap playbook. SSH key authorized for Ansible/Tofu automation.

### hermesagent
LXC `102` — the container that runs this coding agent. 4 GB / 20 GB.

### Cloudflare tunnel
The `cloudflared` LXC (`100`) and its token-secured tunnel exposing selected
homelab services without opening inbound firewall ports.

### bpg/proxmox
The actively maintained Terraform/OpenTofu provider for Proxmox VE. Pinned to
`~> 0.111` in this repo. Registry: <https://registry.terraform.io/providers/bpg/proxmox>.

### `root@pam!terraform`
The API token Terraform uses to authenticate to the Proxmox API. The token is
attached to the `root@pam` user and is independently revocable. `bpg/proxmox`
combines the token ID + secret into a single env var,
`PROXMOX_VE_API_TOKEN=root@pam!terraform=<secret>` (NOT separate `PM_*` vars —
those are the legacy Telmate provider). Endpoint via `PROXMOX_VE_ENDPOINT`.
Never stored in the repo. See ADR-0002.

### `vm_qemu`
A legacy resource alias in `bpg/proxmox` that mirrors the old Telmate provider
shape. **Not used in this repo.** Use `proxmox_virtual_environment_vm` for VMs
and `proxmox_virtual_environment_container` for LXCs.

### R2 / Cloudflare R2
Cloudflare's S3-compatible object storage. Used as the Terraform state backend
for this repo. See ADR-0003. The state bucket is `tesseract-tfstate`
(name chosen at one-time bootstrap).

### `use_lockfile`
S3 backend option (Terraform ≥ 1.10) that enables state locking via S3
conditional writes — no DynamoDB required. Used in this repo so R2 can serve
as a lockable backend.

### State bootstrap (R2)
The one-time manual step of creating the `tesseract-tfstate` bucket, enabling
versioning, and minting a scoped R2 API token. Documented in ADR-0003 and the
runbook. Cannot be automated by the Terraform config that *uses* the bucket as
its backend.

### Inventory map
The `lxcs` and `vms` maps in `terraform/terraform.tfvars`. Source of truth for
"which guests exist and what are their per-guest inputs." See ADR-0005.

### Map key (guest name)
The stable identifier (e.g., `adguard`, `k3s_master01`) used as the key in the
inventory map and as Terraform's resource identity. Renaming = destroy +
recreate. Distinct from the numeric Proxmox `vmid`, which is a field inside
the value.

### Module default
A variable default in `modules/lxc/variables.tf` or `modules/vm/variables.tf`
that captures a value shared by every guest of that kind (e.g., `onboot = true`
for LXCs). Fleet-wide changes happen here, not in tfvars. See ADR-0005.

### Guest kind
Either `lxc` or `vm`. The repo has exactly two modules, one per kind. There
are no family-specific modules (`*arr`, `k3s`, `infra`) — family differences
are data in tfvars, not code.

### Guest shell
The Proxmox-level existence of a guest: CPU, RAM, disk, network, lifecycle
(`onboot`, start/stop), and (for VMs) clone source. This is everything
Terraform owns. Opposite of *in-guest state* (packages, users, services),
which Terraform does **not** own. See ADR-0006.

### In-guest state
Packages, users, services, config files, application data inside a guest.
**Not** owned by Terraform. Currently installed historically via
community-scripts; future ownership deferred (ADR-0006).

### Provisioner
A Terraform mechanism (`remote-exec`, `local-exec`, provider-specific
`initialization` scripts) that runs commands inside or against a guest at
create time. **Forbidden in this repo** for software install — see ADR-0006.
Provisioners are not idempotent in `plan`, run only on create, and tie
software state to VM lifecycle.

### Fact owner
The single system that is authoritative for a given piece of homelab state
(e.g., Terraform owns "guest IP"; manual ops owns "DHCP reservation"). Rule:
every fact has exactly one owner; others are derived. See ADR-0006.

### 4G router (homelab)
The single physical device that is **both** the ISP modem (4G/LTE WAN) **and**
the user's LAN router (DHCP, NAT, firewall, Wi-Fi AP). There is no separate
upstream device. WAN side is ISP-controlled and behind CGNAT (no usable
inbound public IP). LAN side is user-administered but has no API. See ADR-0007.

### CGNAT
Carrier-Grade NAT. The ISP runs it on the 4G path; the homelab router gets a
private address and there is **no usable inbound public IP**. This is *why*
remote access relies on Tailscale + Cloudflare tunnel rather than port
forwarding. See ADR-0007.

### `expected_ip`
The tfvars field recording what IP a guest **is observed** to have (via the
router's DHCP). Named `expected_ip` (not `ip`) to signal that Terraform
records but does **not enforce** it. See ADR-0007.

### Sentinel check
A CI script that compares each guest's `expected_ip` (from tfvars) against
its **actual** IP (from Proxmox guest-net info, or `arp`/`ping` as fallback).
Detects router-side IP drift that Terraform cannot reconcile — and is more
valuable than on a typical homelab because the consumer 4G router's DHCP
table may not survive reboots. See ADR-0007.

### Tailscale
Mesh VPN used for remote access to the homelab. Bypasses CGNAT entirely (no
public IP needed). Not managed by this repo's Terraform (out of scope); its
config and ACLs reference internal IPs, so IP stability (see ADR-0007)
matters to it.

### Cloudflare tunnel
The inbound tunnel run by the `cloudflared` LXC (`100`). Bypasses CGNAT (no
public IP needed). Its ingress routes to internal homelab IPs, so IP
stability (see ADR-0007) is load-bearing for it.

### `k3s-template` (`104`)
A stopped VM template (Ubuntu 22.04, 4 GB / 20 GB) built by hand and used
historically as the clone source for the 4 k3s VMs (`105`–`108`). **Out of
scope for Terraform** — not a resource, not a data source. Documented in
`docs/runbooks/k3s-template.md` as a manual procedure. See ADR-0008.

### Standalone VM (vs. clone)
How the 4 k3s VMs are modeled in Terraform: as independent VMs with their
own disks, **not** as clones of `104`. The `vm` module has no `clone` block.
The clone is a historical event; ongoing management treats the VMs as
self-contained. See ADR-0008.

### Tier 1 secrets
The current secrets-handling approach: long-lived backend credentials (Proxmox
token + R2 keys) live in a gitignored `.env` locally and GitHub Actions repo
secrets in CI. tfvars is secret-free. See ADR-0009.

### `.env` / `.env.example`
`.env` holds real secret values, is gitignored, and is sourced into the shell
before running `terraform`. `.env.example` holds the same variable names with
placeholder values and is committed to document the contract. See ADR-0009.

### Cloudflare tunnel token (out of scope)
The rotating token consumed by the `cloudflared` service in LXC `100`. Lives
in a `.env` *on that LXC*, **not in this repo, not in CI.** Out of scope per
ADR-0006 (Terraform doesn't configure in-guest software) and ADR-0009.

### Phase 1 (local-first)
The current workflow: operator runs `terraform plan` and `terraform apply`
manually from their laptop. No CI. PRs still used for self-review/audit. See
ADR-0010.

### Phase 2 (Atlantis)
The future workflow: PR-comment-driven Terraform via Atlantis, hosted inside
the LAN (likely LXC `102`), exposed to GitHub via the Cloudflare tunnel.
Deferred — not implemented yet. See ADR-0010.

### Atlantis
Open-source tool for PR-driven Terraform: `atlantis plan` and
`atlantis apply` comments on PRs trigger plan/apply on a server. Webhook-
driven (GitHub pushes PR events to it), so it must be reachable from GitHub —
non-trivial behind CGNAT (ADR-0007). See ADR-0010. <https://www.runatlantis.io/>

### `prevent_destroy`
A Terraform `lifecycle` meta-argument present on every guest resource in this
repo. Prevents `terraform destroy` from removing a guest without editing the
module (which is visible in code review). The always-on safety net,
independent of whether apply runs from the laptop or Atlantis.
