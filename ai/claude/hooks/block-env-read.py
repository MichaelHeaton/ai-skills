#!/usr/bin/env python3
"""Pre-tool-use hook: block Read calls targeting credential .env files."""
import json
import re
import sys
from pathlib import PurePosixPath

data = json.load(sys.stdin)
file_path = data.get("tool_input", {}).get("file_path", "")

# Never block AI workspace config (accounts.shell is NOT matched — only *.env)
normalized = file_path.replace("\\", "/")
if "/.config/claude-skills/" in normalized:
    sys.exit(0)

# Match .env, .env.local, .env.production, etc. but NOT .envrc
if re.search(r"\.env(\.|$)", file_path):
    print(f"Blocked: reading .env files is not allowed ({file_path})", file=sys.stderr)
    sys.exit(1)

sys.exit(0)
