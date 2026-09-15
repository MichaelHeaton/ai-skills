---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: vault-terraform-env-repair
description: Diagnose a broken Vault-to-Terraform credential chain by classifying the failure into exactly one of three classes — config-parse failure, OIDC/auth 403, or break-glass static-token path — then apply only the matching repair. Never prints secret material. Use when Terraform/OpenTofu can't obtain Vault-backed credentials, "vault provider auth failing", "terraform can't reach vault", "OIDC 403 on terraform init/plan", "vault token invalid for terraform", "break glass terraform vault", or any error where local Terraform env wiring for Vault auth fails. Distinct from vault-support (server/policy-side Vault administration — KV2, AppRole, wiki doc gaps) and vault-ssh-fallback (Vault SSH secrets-engine signing failures during host forensics) — this skill is specifically the Terraform-consumer side of a broken credential chain.
compatibility: Requires local Vault CLI and Terraform/OpenTofu CLI access. Does not require write access to Vault policies — diagnosis only.
---

# Vault Terraform Env Repair

Diagnoses why Terraform/OpenTofu can't obtain the Vault-backed credentials it needs, by classifying the failure into exactly one of three classes first — never guess-and-check across fixes. Each class has its own repair path; don't apply another class's fix hoping it also covers this one.

**⚠️ Never print secret material (tokens, passwords, key material) in output at any point in this skill** — classification and repair both work from error text and metadata, not secret values.

## Step 1 — Classify the failure

Read the actual error text before doing anything else. The three classes rarely look alike:

- **Config-parse failure**: Terraform/OpenTofu itself fails before ever contacting Vault — malformed HCL, a missing required provider block, an unset environment variable Terraform expects (`VAULT_ADDR`, `VAULT_NAMESPACE`), or a syntax error in the wrapper script that sets up the environment. Symptom: the error references Terraform/HCL parsing, an unset variable, or a shell/wrapper syntax error — not an HTTP status code from Vault.

- **OIDC/auth 403**: Terraform successfully reaches Vault, but the auth request is rejected — an expired OIDC token, a role binding that doesn't grant the requested Vault policy, or a group/entity mapping that changed. Symptom: an explicit `403` (or `permission denied`) from Vault's own API, typically after a `vault login -method=oidc` step or during the Terraform provider's own auth handshake.

- **Break-glass static-token path**: Someone is (or was) using a long-lived static Vault token as a fallback instead of OIDC, and that token itself is now invalid, revoked, or expired. Symptom: the environment has `VAULT_TOKEN` set directly (rather than relying on OIDC login), and the failure is the token being rejected — not an OIDC handshake at all.

If the symptom doesn't clearly match one class, re-read the raw error rather than guessing — misclassifying sends you down the wrong repair path and can waste more time than the original failure.

## Step 2 — Apply the matching repair only

### Class: config-parse failure

1. Run `terraform validate` (or the OpenTofu equivalent) to isolate whether the failure is HCL syntax or environment setup.
2. Check required environment variables are set and non-empty: `VAULT_ADDR`, `VAULT_NAMESPACE` (if applicable), and any wrapper-script-specific variables — print variable *names* that are unset, never their values if set.
3. If a wrapper script sets up the Vault provider block, lint it directly (`shellcheck` for shell wrappers) rather than debugging through Terraform's own error output, which is often just relaying the wrapper's failure.
4. Fix the parse/config issue and re-run `terraform plan` to confirm it now reaches the actual Vault auth step.

### Class: OIDC/auth 403

1. Confirm the OIDC login itself succeeded: `vault token lookup` should show a valid, non-expired token. If it doesn't, re-run `vault login -method=oidc` first — most "403 from Terraform" cases are actually just an expired local session.
2. If the OIDC login succeeds but Terraform still gets a 403, the token's associated policy doesn't grant what Terraform is requesting. Check the specific path Terraform failed on against the token's capabilities: `vault token capabilities <token> <path>`.
3. If capabilities are missing, this is a policy/role-binding gap, not something to route around locally — escalate to whoever owns the Vault policy for that path rather than reaching for break-glass.

### Class: break-glass static-token path

1. Confirm this really is a break-glass token (long-lived, not tied to a personal OIDC identity) before repairing it as one — check whether it's documented as a break-glass credential in the team's secret inventory.
2. If it is: rotate it through the repo's normal break-glass rotation procedure. Do not extend its life or widen its scope while repairing — a repair is not the moment to also expand what the token can do.
3. If a static token is being used **instead of** OIDC purely out of convenience, with no genuine break-glass justification (OIDC provider outage, emergency access with no other path), this is not a repair — it's a request to fix OIDC properly. Flag it as such rather than just rotating the token and moving on.

## When break-glass is actually appropriate vs. fixing OIDC

Break-glass static tokens exist for **OIDC provider unavailability or genuine emergency access**, not for "OIDC was annoying to set up" or "it worked once as a static token so we kept it." If the underlying reason a static token is in place is a fixable OIDC/config problem (Step 2's other two classes), fix that instead of treating the static token as the permanent solution — a static token left in place after its emergency has passed is a standing credential-hygiene gap, not a resolved incident.

## Verification

After applying the matching repair, re-run `terraform plan` (or `init`, if the failure was earlier in the chain) and confirm it completes without a Vault-related error. A clean plan is the only real confirmation — don't declare the repair done on `vault login` succeeding alone if Terraform itself hasn't been re-tested.
