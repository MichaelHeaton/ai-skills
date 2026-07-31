# Shared paths for install-system / sync-from-system (source with: . scripts/lib/deploy-paths.sh)

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLAUDE_SRC="$REPO_DIR/ai/claude"
SKILLS_SRC="$CLAUDE_SRC/skills"
HOOKS_SRC="$CLAUDE_SRC/hooks"
MEMORY_SRC="$CLAUDE_SRC/memory"
AGENTS_SRC="$CLAUDE_SRC/agents"
CLAUDE_MD_SRC="$CLAUDE_SRC/CLAUDE.md"
CLOG_SRC="$SKILLS_SRC/log-clip/scripts/clog.py"
CLI_FILTER_SRC="$SKILLS_SRC/log-clip/scripts/cli-filter.py"

CURSOR_RULES_SRC="$REPO_DIR/ai/cursor/rules"
CURSOR_RULES_DST="$HOME/.cursor/rules"

SKILLS_DST="$HOME/.claude/skills"
HOOKS_DST="$HOME/.claude/hooks"
AGENTS_DST="$HOME/.claude/agents"
CLAUDE_MD_DST="$HOME/.claude/CLAUDE.md"
CLOG_DST="$HOME/.local/bin/clog"
CLI_FILTER_DST="$HOME/.local/bin/cli-filter"

CONFIG_TEMPLATE="$REPO_DIR/config/local.template.json"
CONFIG_DST_DIR="$HOME/.config/ai-skills"
CONFIG_DST="$CONFIG_DST_DIR/local.json"

ENCODED_REPO="$(echo "$REPO_DIR" | tr '/' '-' | sed 's/^-//')"
MEMORY_DST="$HOME/.claude/projects/$ENCODED_REPO/memory"

SYSTEM_MANIFEST="$REPO_DIR/.deploy/system-manifest.json"
LAST_SYNC="$REPO_DIR/.deploy/last-sync.json"

# Skills removed from repo — delete from ~/.claude/skills on install
RETIRED_SKILLS=(uv-weekly pr-slack)

# Cursor rules removed from repo — delete from ~/.cursor/rules on install
RETIRED_CURSOR_RULES=()
