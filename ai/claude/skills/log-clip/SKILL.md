---
version: 1.2.0
principles_version: 1.0.0
last_updated: 2026-08-25
updated_by: claude
name: log-clip
description: Filtered log capture system for noisy CLI tools (Terraform, Ansible, Vault, Kubernetes). Strips DEBUG/INFO/progress noise, redacts secrets, and saves signal-only output to ~/.claude/logs/ so Claude reads only what matters. Two modes: capture script (user runs the command, pipes through clog) and Claude-side filter (Claude pipes its own tool commands through clog before reading output). Trigger on: "read the last tf log", "show me the filtered log", "run terraform and show me errors only", "pipe through clog", or any time raw Terraform, Ansible, or Vault output is about to be loaded into context — including a second or third raw structured-log paste in the same debugging loop, which is its own recognizable pattern even if the first paste was missed.
compatibility: Requires Python 3. Install via `make install-system` in ai-skills (copies clog to ~/.local/bin/clog).
---

# Log Clip

Noisy tool output is one of the biggest context wasters. A full `terraform apply` or `ansible-playbook` run can be 500–2000 lines; the signal is usually under 20.

**clog** captures, redacts secrets, and filters to signal lines only. Logs land in `~/.claude/logs/` where Claude can read them on demand.

---

## User-side capture (you run the command)

```bash
# Terraform
terraform apply 2>&1 | clog tf

# Ansible
ansible-playbook playbook.yml -i inventory 2>&1 | clog ansible

# Vault
vault operator unseal 2>&1 | clog vault

# Kubernetes
kubectl apply -f . 2>&1 | clog k8s

# Anything else (generic error filter)
some-command 2>&1 | clog
```

Output: `~/.claude/logs/tf-2026-05-19T14-32-01.log`
After running: tell Claude `"read the last tf log in ~/.claude/logs/"` — Claude reads the filtered file, not the raw output.

---

## Claude-side filter (Claude runs the command)

When Claude needs to run a noisy command, it should pipe through `clog` and read the filtered file rather than capturing raw output into context:

```bash
# Claude runs this instead of capturing raw output directly:
terraform plan 2>&1 | clog tf
# Then reads: ~/.claude/logs/tf-<timestamp>.log
```

If `clog` is not installed, Claude should apply a manual filter: grep for `Error:|Warning:|Plan:|Apply complete` rather than reading the full output.

**Same applies when Claude hands the user a command to run themselves.** If Claude is about to suggest a command likely to print a secret to stdout — `vault operator init`, `vault operator unseal`, `aws sts get-session-token`, anything printing tokens/keys/credentials — default to suggesting it piped through `clog <tool>` (or `clog auto` if no specific tool filter fits) rather than a bare command, and tell the user to read the filtered log back rather than pasting raw output into chat. This closes the actual failure mode `clog`'s redaction exists for: a secret printed to a terminal, then manually copied somewhere it shouldn't go — including into an AI prompt. `secret-scan-prompt` (a global `UserPromptSubmit` hook, unrelated skill) is the backstop for anything pasted raw anyway; this convention is the first line of defense that avoids needing the backstop at all.

Once a filtered log already exists — whether from manual `clog` piping above or a separate automatic-capture pipeline if one is installed — `cli-filter <tool>` is the preferred way to read the latest one, rather than hunting through `~/.claude/logs/` manually:

```bash
cli-filter tf              # prints the latest filtered tf log
cli-filter ansible -n 3    # prints the 3 most recent filtered ansible logs
```

---

## What gets filtered

| Tool | Kept | Stripped |
| --- | --- | --- |
| `tf` / `terraform` | Errors, warnings, plan summary, state changes (+/-/~), resource names, Apply/Destroy result | Progress dots, Refreshing state..., provider version noise, blank lines |
| `ansible` | TASK, PLAY, RECAP, failed, fatal, changed, WARNING, UNREACHABLE | ok:, skipping:, Gathering Facts (when successful), timing |
| `vault` | Errors, key/value output, lease info, seal status, permission denied | Verbose request/response headers, progress |
| `k8s` | Errors, CrashLoop, OOMKilled, NotReady, Failed events | Successful creates/updates, Running pods |
| `ci` | Failed step name, exit code, failing command, last 200 relevant lines | Successful step output, install/download noise, build chatter |
| `auto` | Lines matching error/warn/fail/panic/denied/timeout | Everything else |

---

## Secrets redaction (always on)

Before filtering, clog redacts:

- AWS access keys (`AKIA...`)
- passwords, tokens, api_key, bearer values in key=value format
- Vault tokens, legacy and current formats (`s.XXXX`, `hvs.XXXX`, `hvb.XXXX`, `hvr.XXXX`)
- Vault unseal keys and recovery keys (`Unseal Key N: ...`, `Recovery Key N: ...`)
- Private key blocks
- Authorization headers

Redacted values become `[REDACTED]` inline. Raw output is kept in `~/.claude/logs/.raw-*` hidden files for your own debugging — Claude should not read raw files.

---

## Manual triage (no clog)

When clog isn't available, apply evidence ordering before asking for full output:

| Tool | Ask for first | Ask for last |
| --- | --- | --- |
| Terraform | Error block + affected resource + workspace | Full plan |
| Ansible | Failed task name + module + stderr/stdout | Verbose run (`-vvv`) |
| CI/CD | Failed step name + exit code + last 200 lines | Full job log |
| Incident / general | Error signature + narrow time window | Full dump |

**Stop log spread**: never request more output without naming the hypothesis it would test and the exact slice needed. "Send more logs" is not a valid request — "send the stderr from the failing Ansible task on host X" is.

---

## Triage response format

When analyzing filtered output, structure the response as:

1. **What failed** — one sentence
2. **Primary evidence** — the specific lines that matter
3. **Most likely cause(s)** — ranked, not exhaustive
4. **Missing evidence** — what would confirm the diagnosis
5. **Next exact slice** — precisely what to fetch (if still needed)
6. **Next remediation step** — one concrete action

---

## Reading logs

Claude should always read the most recent log for a given tool. Prefer `cli-filter` over manually globbing the directory:

```bash
cli-filter tf
```

Or, if `cli-filter` isn't installed:

```bash
# Find the latest tf log
ls -t ~/.claude/logs/tf-*.log | head -1
```

Or the user can say: "read the last tf log" and Claude will find and read it from `~/.claude/logs/`.

---

## Installation

`clog` and `cli-filter` are installed by `ai-skills/scripts/install-system.sh`:

```bash
# Creates: ~/.local/bin/clog → ai/claude/skills/log-clip/scripts/clog.py
# Creates: ~/.local/bin/cli-filter → ai/claude/skills/log-clip/scripts/cli-filter.py
make install-system   # from ~/Projects/personal/ai-skills/
```

Make sure `~/.local/bin` is in your `$PATH`.
