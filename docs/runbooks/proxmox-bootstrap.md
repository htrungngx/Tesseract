# Runbook: Proxmox API token (one-time bootstrap)

**Related ADR:** [0002](../adr/0002-proxmox-provider-and-auth.md).

Creates the `root@pam!terraform` API token that Terraform uses to talk to
Proxmox. Done once; rotated only on leak.

## Steps

1. Log into Proxmox web UI as `root@pam`.
2. **Datacenter → Permissions → API Tokens → Add.**
3. User: `root@pam`. Token ID: `terraform`. Leave "Privilege Separation"
   **unchecked** (the token inherits root privileges — needed for the
   shell-management scope in ADR-0006).
4. Copy the generated **secret** immediately — it's shown once.
5. Construct the combined token string:
   `root@pam!terraform=<secret>`
6. Put it in your `.env` (see `.env.example`) as `PROXMOX_VE_API_TOKEN`.
7. Also set `PROXMOX_VE_ENDPOINT=https://192.168.1.21:8006` and
   `PROXMOX_VE_INSECURE=true` (pve01 uses a self-signed cert).

## Verify

```sh
set -a; . ./.env; set +a
cd terraform && terraform init
terraform plan    # should reach Proxmox without auth errors
```

## Rotation (only if it leaks)

1. Proxmox UI → API Tokens → `root@pam!terraform` → **Delete**.
2. Re-create with the same name (new secret generated).
3. Update `.env` and CI secrets (Phase 2).
