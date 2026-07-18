# Runbook: R2 state bucket (one-time bootstrap)

**Related ADR:** [0003](../adr/0003-cloudflare-r2-state-backend.md).

The R2 bucket cannot be created by the Terraform config that uses it as a
backend (chicken-and-egg). This is a one-time manual step.

## Steps

1. Cloudflare dashboard → **R2** → **Create bucket**.
2. Bucket name: `tesseract-tfstate` (must match `terraform/backend.tf`).
3. **Enable object versioning** on the bucket (under Settings). This is what
   makes state recovery possible (see `state-recovery.md`).
4. Go to **R2 → Manage R2 API Tokens → Create API Token**.
   - Permissions: **Object Read & Write**.
   - Specify bucket: `tesseract-tfstate` only (least privilege).
5. Copy the **Access Key ID** and **Secret Access Key**.
6. Find your Cloudflare account ID (dashboard URL or right sidebar). Construct
   the S3 endpoint: `https://<accountid>.r2.cloudflarestorage.com`.
7. Put all three values in `.env` (see `.env.example`):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_ENDPOINT_URL_S3`

## Verify the lock mechanism

`use_lockfile = true` relies on R2 supporting S3 conditional writes. Smoke-test
before trusting it with real state:

```sh
cd terraform && terraform init
# Init should succeed and create the lock object on first plan.
terraform plan
```

If you see a locking error at this point, R2 conditional writes aren't working
— stop and debug before going further.

## What lives where

- **Bucket:** `tesseract-tfstate` (Cloudflare R2)
- **State key:** `default.tfstate` (single-environment homelab today)
- **Versioning:** on, all versions kept (state is tiny; cost is negligible)
- **Access:** one R2 API token scoped to this bucket only
