# Remote state backend: Cloudflare R2 via the S3 backend.
#
# See ADR-0003. R2 is S3-API-compatible. Locking uses S3 conditional writes
# (`use_lockfile = true`, Terraform >= 1.10) — no DynamoDB needed.
#
# All sensitive values are read from environment variables (see ADR-0009):
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ENDPOINT_URL_S3, AWS_REGION
# These are *not* set in this block — the backend reads them from env directly.

terraform {
  backend "s3" {
    # Bucket is created manually (see ADR-0003 "Bootstrap"). Rename if yours
    # differs.
    bucket = "tesseract-tfstate"

    # Single-environment homelab today → static key. If a second environment
    # is ever added, switch to the `workspaces { prefix = ... }` sub-block
    # (modern Terraform equivalent of the legacy env:/ path templating) —
    # each `terraform workspace` then writes under its own prefix.
    key = "default.tfstate"

    region                      = "auto"
    use_lockfile                = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true

    # R2 endpoint comes from $AWS_ENDPOINT_URL_S3 — modern Terraform reads it
    # automatically; no `endpoint` arg here.
  }
}
