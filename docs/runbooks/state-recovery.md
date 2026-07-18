# Runbook: Terraform state recovery (R2)

**Related ADR:** [0003](../adr/0003-cloudflare-r2-state-backend.md) — state
on Cloudflare R2, object versioning enabled.

State corruption or a bad apply is recoverable because R2 keeps every version
of the state object. This runbook covers the two common recoveries.

## Case 1: roll back to a previous state version

Use when a `terraform apply` produced unwanted changes and you want to
restore the prior state object (not the prior *infrastructure* — that's
separate).

1. Cloudflare dashboard → R2 → `tesseract-tfstate` → object
   `env:/default/terraform.tfstate` → **Versions**.
2. Find the last known-good version (timestamped). Download it.
3. Upload it back as the current version of the same key (overwrite). R2
   treats this as a new version; the bad one is preserved as history.
4. `cd terraform && terraform init && terraform plan` — should now reflect
   the rolled-back state.
5. **Do NOT `apply` yet.** Inspect the plan. If real infrastructure has
   drifted from this state, the plan will show how to reconcile.

## Case 2: lock is stuck (run died holding the lock)

Use when `terraform` complains that the state is locked and you can't proceed.

1. `cd terraform && terraform force-unlock <LOCK_ID>` (the lock ID is in the
   error message).
2. Only do this if you're certain no other `terraform` process is running.
   The lock exists to prevent corruption; forcing it is a last resort.
3. If unsure, wait 10 minutes first — stale locks from killed runs are the
   usual cause.

## What "treat state as secret" means in practice

- Never `cat terraform.tfstate` in a PR description or chat.
- Never paste state into an issue.
- The R2 bucket is private; state only ever lives on R2 and on your laptop
  transiently during `plan`/`apply`.
