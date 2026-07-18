# ADR 0003: Store Terraform state in Cloudflare R2 via the S3 backend

- **Status:** Accepted
- **Date:** 2026-07-17

## Context

Once the 14 existing Proxmox guests are imported (ADR-0001), `terraform.tfstate`
becomes the irreplaceable map between code and running infrastructure. The
state backend must be:

- **Survivable independently of the homelab.** If `pve01` fails, the state that
  describes `pve01` must not fail with it.
- **Lockable.** Concurrent `terraform apply` (especially once CI is in place)
  must not corrupt state.
- **Cheap at homelab scale** (state is kilobytes).
- **Secrets-aware.** Proxmox guest config and any secrets passed to the
  provider end up in state, so the backend itself must be access-controlled.

Candidate backends:

| Option | Verdict |
| --- | --- |
| Local state committed to git | **Rejected.** Plaintext secrets in the repo violates ADR-0002's hygiene rule. |
| Local state `.gitignore`'d | **Rejected.** No backup, no concurrency, blocks CI. |
| State hosted on Proxmox (e.g., MinIO LXC) | **Rejected.** Correlates the failure of state with the failure of the thing it describes — worst case. |
| HCP Terraform (D1) | Runner-up. Adds a vendor account; unnecessary given CI plans (Q10). |
| **Cloudflare R2 via S3 backend (D3)** | **Chosen.** |

## Decision

Use **Cloudflare R2** as the remote state backend, accessed via Terraform's
built-in **`backend "s3"`** (R2 is S3-API-compatible).

### Bucket layout

- **One bucket** for the whole homelab: `tesseract-tfstate` (exact name chosen
  at bootstrap; the bucket itself is created manually, see *Bootstrap* below).
- **Per-environment key prefix**: `env:/{workspace}/terraform.tfstate`.
  Initial workspace is `default` (homelab is a single environment; the prefix
  leaves room for a future `staging`/`dr` split without re-architecting).
- **Object versioning enabled on the bucket** for accidental-overwrite recovery.
- **Lifecycle policy**: keep all versions indefinitely (state is tiny; the cost
  is rounding error).

### Locking

- **`use_lockfile = true`** on the S3 backend. Introduced in Terraform 1.10,
  this uses S3 conditional writes (`If-None-Match: *`) to atomically create a
  lock object — **no DynamoDB required**.
- **Minimum Terraform version pinned to `>= 1.10`** in the repo's
  `.terraform-version` / `versions.tf`.
- **Critical dependency**: R2 must implement S3 conditional writes. Cloudflare
  publishes [their own R2 backend guide](https://developers.cloudflare.com/terraform/advanced-topics/remote-backend/),
  so this is supported — but it will be smoke-tested as part of day-1 bring-up
  before any real `apply`.

### Access

- R2 access keys (Access Key ID + Secret) created in the Cloudflare dashboard
  with **a token scoped to this single bucket** (read + write + list).
- Keys live only in the host/CI environment (`AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY`, `AWS_ENDPOINT_URL_S3` pointing at the R2 S3 endpoint),
  **never in the repo**. See ADR on secrets (forthcoming).
- Bucket is private; no public access.

## Bootstrap (one-time, manual)

The R2 bucket **cannot** be created by the Terraform configuration that uses it
as a backend (chicken-and-egg). Manual steps, done once and recorded in the
runbook:

1. Cloudflare dashboard → R2 → create bucket `tesseract-tfstate`.
2. Enable object versioning on the bucket.
3. Create R2 API token scoped to this bucket (read/write/list).
4. Store the Access Key ID + Secret in your password manager and (later) in CI
   secrets — see ADR on secrets.
5. Run `terraform init` — Terraform sees the empty key path and initializes
   fresh state.

After bootstrap the bucket is hands-off; only Cloudflare-side maintenance
(versioning/lifecycle/billing) touches it.

## Consequences

- **State survives Proxmox failure.** Recovery = new Proxmox install + restore
  guests from backups + re-point Terraform. State is intact on R2.
- **CI can run `plan` safely.** Concurrent runs serialize on the lock; no
  corrupted state.
- **State still contains secrets** (guest config, anything passed via provider).
  Mitigated by: private R2 bucket, scoped token, versioning for forensic
  recovery. Not mitigated by: anything — treat state as secret, never log it,
  never `cat` it in CI.
- **Terraform version floor is 1.10** across local dev and CI. Pinned via
  `.terraform-version` (tfenv/tenv) and the CI image tag.
- **Cloudflare is now in the critical path** for Terraform operations. If
  Cloudflare has an outage, we can't `apply`. Acceptable for a homelab; would
  not be acceptable for prod infra at scale.
- **One-time bootstrap step is manual and documented** in the runbook. Anyone
  forking this repo does it once.

## References

- S3 backend docs: <https://developer.hashicorp.com/terraform/language/backend/s3>
- Cloudflare's R2 backend guide: <https://developers.cloudflare.com/terraform/advanced-topics/remote-backend/>
- S3 native locking explainer: <https://www.bschaatsberiden.com/s3-native-state-locking>
- R2 + Terraform issue (status tracker): <https://github.com/hashicorp/terraform/issues/33847>
