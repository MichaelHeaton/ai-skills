#!/usr/bin/env python3
"""Pre-tool-use hook: block Read calls targeting .env files."""
import sys
import json
import re

data = json.load(sys.stdin)
file_path = data.get("tool_input", {}).get("file_path", "")

# Match .env, .env.local, .env.production, etc. but NOT .envrc
if re.search(r"\.env(\.|$)", file_path):
    print(f"Blocked: reading .env files is not allowed ({file_path})", file=sys.stderr)
    sys.exit(1)
