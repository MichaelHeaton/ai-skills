#!/usr/bin/env python3
"""UserPromptSubmit hook: block prompts that contain secret-shaped text.

Catches the case where a real API key, Vault token, or unseal key was pasted
into a prompt before the user reviewed it — the point where it's still
possible to stop, vs. after it's already in the model's context.

Scans with gitleaks (default ruleset: AWS keys, generic high-entropy API
keys, etc. — the same rules already proven to catch Vault's hvs./s. token
formats via the generic-api-key rule). Fails open if gitleaks isn't
installed or errors, so a missing dependency doesn't brick every prompt.
"""
import json
import shutil
import subprocess
import sys

data = json.load(sys.stdin)
prompt = data.get("prompt", "")

if not prompt.strip():
    sys.exit(0)

gitleaks = shutil.which("gitleaks")
if not gitleaks:
    print(
        "WARN: gitleaks not found; prompt secret-scan hook disabled (brew install gitleaks)",
        file=sys.stderr,
    )
    sys.exit(0)

try:
    result = subprocess.run(
        [gitleaks, "detect", "--pipe", "--no-banner", "--exit-code", "2",
         "-f", "json", "-r", "-"],
        input=prompt,
        capture_output=True,
        text=True,
        timeout=10,
    )
except subprocess.TimeoutExpired:
    print("WARN: gitleaks scan timed out; allowing prompt through", file=sys.stderr)
    sys.exit(0)

if result.returncode == 2:
    try:
        findings = json.loads(result.stdout)
        rules = sorted({f.get("RuleID", "unknown") for f in findings})
    except (json.JSONDecodeError, AttributeError):
        rules = ["unknown"]
    print(
        f"BLOCKED: this message looks like it contains {len(rules)} potential "
        f"secret(s) (rule: {', '.join(rules)}). Remove/redact the value and "
        "resubmit. If it's a real credential, rotate it regardless.",
        file=sys.stderr,
    )
    sys.exit(2)

if result.returncode not in (0, 2):
    print(f"WARN: gitleaks exited {result.returncode}; allowing prompt through", file=sys.stderr)

sys.exit(0)
