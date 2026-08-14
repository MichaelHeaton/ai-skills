---
version: 1.0.1
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
name: local-automation-setup
description: Set up recurring *local* automation (macOS launchd, or cron on Linux) for tasks that need local filesystem or install access — the built-in schedule/Routine tooling only creates cloud agents with no local machine access. Use when a recurring task needs to read local files, hit localhost services, or run installed CLI tools, and the built-in cloud scheduler isn't the right fit. Triggers on "set up a recurring local check", "schedule this to run locally", "make this a launchd job", "add a cron job for this", or after discovering a cloud-scheduled task actually needs local access.
compatibility: macOS (launchd) or Linux (cron). Requires shell access to the target machine.
---

# Local Automation Setup

The built-in cloud scheduler (`schedule`/Routines) creates isolated cloud sessions — a git checkout, no local filesystem, no installed tools, no localhost access. That's the wrong shape for anything that needs to read local state, hit a local service, or run a tool only installed on this machine. This skill builds the local equivalent.

**Confirm the cloud scheduler is actually wrong first** — if the task only needs a git checkout and can run headless in an isolated container, the built-in cloud scheduler is simpler and needs no machine-specific setup. Reach for this skill specifically when the task fails that test.

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
