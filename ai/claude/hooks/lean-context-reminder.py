#!/usr/bin/env python3
"""UserPromptSubmit hook: append a compact lean-context reminder once per session."""
import sys
import json
import os
from pathlib import Path

FLAG = Path.home() / ".claude" / ".lean-context-session"
data = json.load(sys.stdin)

# Only fire on the first prompt of each shell session (flag cleared on new terminal)
ppid = str(os.getppid())
if FLAG.exists() and FLAG.read_text().strip() == ppid:
    sys.exit(0)

FLAG.write_text(ppid)
print("[lean] narrow reads · batch files · fresh session on task change · /compact when thread grows")
