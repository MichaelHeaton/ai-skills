---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-08-16
updated_by: claude
name: local-automation-setup
description: Set up recurring *local* automation (macOS launchd, or cron on Linux) for tasks that need local filesystem or install access — the built-in schedule/Routine tooling only creates cloud agents with no local machine access. Use when a recurring task needs to read local files, hit localhost services, or run installed CLI tools, and the built-in cloud scheduler isn't the right fit. Triggers on "set up a recurring local check", "schedule this to run locally", "make this a launchd job", "add a cron job for this", or after discovering a cloud-scheduled task actually needs local access.
compatibility: Local machine only — launchd/cron have no cloud/web-session equivalent; use the built-in Routine scheduler (create_trigger) there instead. macOS (launchd) or Linux (cron). Requires shell access to the target machine.
---

# Local Automation Setup

The built-in cloud scheduler (`schedule`/Routines) creates isolated cloud sessions — a git checkout, no local filesystem, no installed tools, no localhost access. That's the wrong shape for anything that needs to read local state, hit a local service, or run a tool only installed on this machine. This skill builds the local equivalent.

**Confirm the cloud scheduler is actually wrong first** — if the task only needs a git checkout and can run headless in an isolated container, the built-in cloud scheduler is simpler and needs no machine-specific setup. Reach for this skill specifically when the task fails that test.

## Known limitation: fresh-session Routines can't attach repo access

Before assuming the built-in cloud scheduler covers any task that "only needs a git checkout," confirm it also needs **write** access — read-only public-repo work is fine, but push access is currently a dead end for a fresh-session Routine.

`create_trigger` in fresh-session mode (`create_new_session_on_fire: true`) has no way to pre-attach a specific repo with push access to the sessions it spawns. Confirmed in [ai-skills#379](https://github.com/MichaelHeaton/ai-skills/issues/379):

- The spawned session has no `mcp__github__*` tools, and no `add_repo` tool either — the mechanism an interactively-created session normally uses to attach a repo with push credentials.
- `gh` CLI can be installed manually and authenticates fine, but every GitHub API call against the target repo is rejected with "GitHub access to this repository is not enabled for this session. Use add_repo to request access" — with no `add_repo` tool exposed to call.
- Repo access granted via `add_repo` is per-session, not per-environment. Attaching it in one session (e.g. an interactive session) does not propagate to a Routine-fired session spawned later in the same environment.

**Net effect**: a fresh-session Routine can only do work that fits inside read-only public-repo access. Anything that needs to commit, open a PR, or close a ticket — hits a wall before touching anything.

**Workarounds, both with real tradeoffs:**

- **Persistent-session Routine** (`persistent_session_id` bound to a session that already has the repo attached) — access works, but `create_trigger`/`update_trigger` reject the `notifications` parameter for persistent-session Routines, so completion push/email is lost. Context and state also accumulate across fires instead of starting clean each time.
- **Leave the fresh-session Routine disabled** and invoke the skill interactively instead, in a session that already has repo access. This is the safe default until a pre-attach mechanism exists.

This is a harness-level gap in `create_trigger` itself (no `source_url`-equivalent parameter for fresh-session repo access), not something a skill or a repo-side change can work around. Re-check ai-skills#379 before assuming this has been fixed — if it has, this section is stale and should be trimmed.

## 1. Write the wrapper script

Every scheduled job gets a small wrapper, not the raw command inline in the plist/crontab — this makes logging, error handling, and manual re-runs consistent.

```bash
#!/usr/bin/env bash
set -euo pipefail
LOG="$HOME/.local/log/<job-name>.log"
mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
<the actual command>
```

Place it somewhere durable, e.g. `~/.local/bin/<job-name>.sh`, and `chmod +x` it.

## 2a. macOS — launchd plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.user.JOB_NAME</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>/Users/YOUR_USERNAME/.local/bin/JOB_NAME.sh</string></array>
  <key>StartInterval</key><integer>3600</integer>
  <key>RunAtLoad</key><false/>
</dict>
</plist>
```

Replace `JOB_NAME` and `YOUR_USERNAME` with real values — angle-bracket placeholders (`<job-name>`) collide with XML's own tag syntax here and produce a plist launchd will refuse to load, unlike in the shell commands below where angle brackets are harmless.

Save to `~/Library/LaunchAgents/com.user.<job-name>.plist`, then load it:

```bash
launchctl load ~/Library/LaunchAgents/com.user.<job-name>.plist
```

Use `StartInterval` (seconds) for "every N", or `StartCalendarInterval` (hour/minute dict) for a fixed daily time — don't mix both in one plist.

## 2b. Linux — cron

```bash
crontab -e
# add: 0 * * * * /bin/bash $HOME/.local/bin/<job-name>.sh
```

## 3. Verify

**launchd**: `launchctl list | grep com.user.<job-name>` shows it loaded; check the log file after the next expected run.

**cron**: `crontab -l` shows the entry; check the log file, and check `/var/log/syslog` (or `journalctl -u cron`) if the log file never appears — cron failures are often silent at the job level.

## 4. Report

State the job name, schedule, wrapper script path, and log path — so the user can find and modify it later without re-deriving the setup:

```
✓ com.user.doctor-check — hourly, wrapper at ~/.local/bin/doctor-check.sh
  logs: ~/.local/log/doctor-check.log
```
