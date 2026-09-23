---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-09-23
updated_by: claude
name: vault-ssh-fallback
description: Recover a stalled host-forensics investigation when Vault SSH secrets-engine signing fails — the sign response is missing the expected `data`/signed-key field, the signing endpoint itself errors, or a wrapper script around it (e.g. `pve-ssh`) fails. Surfaces the failure explicitly, switches to operator-pasted evidence (journalctl output, log tails) in place of live SSH access, and resumes the original investigation instead of stalling it. Trigger on: `vault write ssh/sign/<role>` failing, a signed SSH cert missing from the response, `pve-ssh` (or similar wrapper) erroring out, "Vault SSH signing failed", "can't get a signed cert", "SSH CA sign request failed". Not for general Vault KB/doc questions or auth-method migrations — see `vault-support` for those.
compatibility: Requires an active host-forensics or diagnostic investigation already in progress that depends on live SSH access via a Vault-signed cert.
---

# Vault SSH Fallback

When Vault's SSH secrets engine fails to sign a certificate, the agent has no way to SSH into the target host. This skill keeps the underlying investigation moving by switching to operator-pasted evidence instead of live shell access — it does not attempt to work around, retry silently, or otherwise route past the signing failure.

## Proactive check — near-expiry cert (before this skill's fallback would even trigger)

Before SSHing via an ansible/Vault-signed cert, check whether it's about to age out — short-lived certs (e.g. ~5-minute TTL) can expire mid-session, and a stale cert fails SSH with `Permission denied (publickey)` even though signing itself worked fine.

- **Check the validity window first.** Run `ssh-keygen -L -f ~/.ssh/ansible_ed25519-cert.pub` (or the actual cert path in use) and parse the `Valid:` line's end timestamp.
- **If remaining TTL is under ~60 seconds, or the cert has already expired**, run the repo/workstation's sign helper (e.g. `scripts/sign-vault-ssh-cert.sh` — the exact path is workstation-specific) to re-sign before retrying the SSH attempt. This is a routine refresh, not a sign failure — don't ask the operator to paste a key for this case.
- **If remaining TTL is comfortably above the threshold, don't re-sign.** This is a preventive check, not a blanket re-sign-every-time policy — only act when the cert is actually near expiry or already expired.
- **If the re-sign attempt itself fails** (the sign call errors, or the wrapper script fails), that's not this check's job to handle further — fall through to the existing "When this triggers" / Step 1–3 fallback flow below. The near-expiry check is a pre-check that can hand off into the existing failure path; it isn't a separate skill.

## When this triggers

Any of the following, encountered mid-investigation:

- `vault write ssh/sign/<role> ...` (or equivalent Vault SSH secrets-engine sign call) returns a response with no `data` field or no signed-key field where one is expected.
- The signing endpoint itself errors (permission denied, sealed vault, expired token, connection failure).
- A wrapper script around the sign flow (referred to in this org as `pve-ssh`, but treat any such wrapper equivalently) exits non-zero or fails to produce a usable cert.
- The proactive near-expiry re-sign above was attempted and itself failed.

## Step 1 — Surface the failure explicitly

Do not silently retry the sign request, fall back to a different auth path, or route around the failure without the operator seeing what happened.

State plainly — **redact per the Non-negotiable section below before including any of the following in the conversation, a ticket, or any other output**, since raw Vault error bodies are exactly where a token or key fragment is most likely to leak:

- **What command failed** — the exact `vault write ssh/sign/...` invocation or wrapper command (e.g. `pve-ssh <host>`).
- **What error came back** — the actual error text or the shape of the malformed response (e.g. "response returned but `data` key was absent"). Redact before pasting — this is the single most likely place secret material leaks, since it's raw output from Vault, not something you composed yourself.
- **What this blocks** — name the specific step of the original investigation that needed the signed cert (e.g. "blocks pulling `journalctl` from host X").

## Step 2 — Switch to direct-paste evidence collection

Since live SSH access isn't available, ask the operator to run the needed commands themselves and paste back the output.

- Name the **specific commands** the investigation actually needs — don't ask for a generic dump. Examples:
  - `journalctl -u <service> --since "<time>" --until "<time>"`
  - `journalctl -b -p err` (current boot, errors only)
  - Relevant log tails: `tail -n 200 /var/log/<service>.log`
  - Any service-status or config-check command the original investigation was going to run over SSH
- Tell the operator **where to run each command** (locally, or on the target host directly — since the agent can't reach it).
- Ask them to **paste the output back** into the conversation.

## Step 3 — Resume the original investigation

Treat the SSH failure as a detour, not a dead end.

- Take the pasted evidence and continue the original diagnostic line of work exactly as if it had come from a live SSH session.
- Don't restart the investigation from scratch or ask the operator to re-explain context already established before the sign failure.
- If the pasted evidence is incomplete, ask a **targeted follow-up** for the specific missing piece rather than a fresh broad dump.

## Non-negotiable — never handle CA/token material

This skill exists to collect diagnostic output, not secrets. Never echo, log, or ask the operator to paste:

- Vault tokens (root, wrapped, or otherwise)
- SSH CA private key material
- Any raw credential from the failed sign response

If a Vault error message itself contains token or key material, redact it before including it in Step 1's failure statement or in any ticket/output this skill produces. Only diagnostic output that doesn't require live shell access — logs, command results, service status — is in scope for Step 2's paste request.
