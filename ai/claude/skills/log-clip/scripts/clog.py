#!/usr/bin/env python3
"""
clog — capture and filter noisy command output for Claude
Usage: command 2>&1 | clog [tf|ansible|vault|k8s|auto]
Output: filtered + secrets-redacted log saved to ~/.claude/logs/
"""

import sys
import re
import os
from datetime import datetime
from pathlib import Path

tool = sys.argv[1].lower() if len(sys.argv) > 1 else "auto"
log_dir = Path.home() / ".claude" / "logs"
log_dir.mkdir(parents=True, exist_ok=True)

timestamp = datetime.now().strftime("%Y-%m-%dT%H-%M-%S")
outfile = log_dir / f"{tool}-{timestamp}.log"
rawfile = log_dir / f".raw-{tool}-{timestamp}.log"

text = sys.stdin.read()
rawfile.write_text(text)
raw_lines = len(text.splitlines())

# ── Secrets redaction ──────────────────────────────────────────────────────────
REDACT = [
    (r"AKIA[0-9A-Z]{16}", "[AWS_KEY_REDACTED]"),
    (r"(?i)(password|passwd|pwd|secret|token|api[_-]?key|bearer)\s*[:=]\s*\S{8,}", r"\1=[REDACTED]"),
    (r"(?i)(unseal key|recovery key)\s*\d*\s*[:=]\s*\S{8,}", r"\1=[REDACTED]"),
    (r"\b(?:hvs|hvb|hvr|s)\.[A-Za-z0-9_-]{20,}", "[VAULT_TOKEN_REDACTED]"),
    (r"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----",
     "[PRIVATE_KEY_REDACTED]"),
    (r"(?i)(aws_secret_access_key)\s*[:=]\s*\S+", r"\1=[REDACTED]"),
    (r"(?i)(authorization:\s*Bearer\s+)\S+", r"\1[TOKEN_REDACTED]"),
]

def redact(s: str) -> str:
    for pattern, replacement in REDACT:
        s = re.sub(pattern, replacement, s)
    return s

# ── Per-tool noise filters ─────────────────────────────────────────────────────
FILTERS = {
    "tf": re.compile(
        r"Error:|Warning:|error:|warning:|Plan:|Apply complete|Destroy complete|"
        r"Changes to Outputs|No changes\.|must be replaced|"
        r"^\s*[+\-~<≡] |\bmodule\.|^(Apply|Destroy|Plan):|"
        r"InvalidClientTokenId|AuthorizationError|AccessDenied"
    ),
    "terraform": None,  # alias set below
    "ansible": re.compile(
        r"TASK \[|PLAY \[|PLAY RECAP|failed:|fatal:|ERROR|WARNING|changed:|"
        r"UNREACHABLE|msg:|skipping: \[.*\] =>.*error"
    ),
    "vault": re.compile(
        r"(?i)error|warning|key\s+value|success!|path\s*=|lease_id|expiration|"
        r"token\s*[:=]|sealed|unseal|recovery key|root token|permission denied"
    ),
    "k8s": re.compile(
        r"Error|error|Warning|OOMKilled|CrashLoop|Pending|Failed|"
        r"ImagePull|Evicted|Terminating|ContainerCreating|NotReady"
    ),
}
FILTERS["terraform"] = FILTERS["tf"]
GENERIC = re.compile(
    r"(?i)error|warn|fatal|fail|exception|traceback|panic|critical|"
    r"denied|forbidden|unauthorized|timeout|refused|killed"
)

def filter_lines(text: str, tool: str) -> list[str]:
    pattern = FILTERS.get(tool, GENERIC)
    return [line for line in text.splitlines() if line.strip() and pattern.search(line)]

# ── Process ────────────────────────────────────────────────────────────────────
redacted = redact(text)
filtered = filter_lines(redacted, tool)
filtered_count = len(filtered)

header = (
    f"# clog: {tool} — {timestamp}\n"
    f"# {raw_lines} lines → {filtered_count} lines (raw: {rawfile.name})\n\n"
)
outfile.write_text(header + "\n".join(filtered) + "\n")

print(f"✓ {outfile}  ({raw_lines} → {filtered_count} lines)", file=sys.stderr)
print(f'  Tell Claude: "read the last {tool} log in ~/.claude/logs/"', file=sys.stderr)
