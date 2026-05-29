---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-05-27
updated_by: human
name: youtube-watch
description: Create a GitHub Issue for a YouTube video to watch later. Fetches the real title, channel, duration, and description via yt-dlp. Creates the issue with the user story template, routes it to the correct project, and logs it. Use when the user shares a YouTube URL and wants to track it as a watch task, or says "add this to my watch list", "I want to watch this later", or pastes a youtube.com URL.
---




Create a "Watch:" GitHub Issue for a YouTube video with full metadata fetched from yt-dlp.

## Steps

### 1. Fetch video metadata

```bash
yt-dlp --dump-json --no-download "{URL}" 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('TITLE:', d.get('title',''))
print('CHANNEL:', d.get('uploader',''))
print('DURATION:', d.get('duration_string',''))
print('DESC:', d.get('description','')[:500])
"
```

Extract:

- **title** — exact video title
- **channel** — uploader/channel name
- **duration** — runtime
- **description** — first 500 characters (truncate at a sentence boundary if possible)

If yt-dlp fails (private video, age-gated, etc.), fall back to the YouTube oEmbed API for the title only:

```bash
curl -s "https://www.youtube.com/oembed?url={URL}&format=json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('title',''))"
```

### 2. Determine domain and priority

Ask the user if not obvious from context:

- **domain**: one of `homelab`, `learning`, `work-primary`, `client-contract`, `personal`, `mtb`, `iot`
- **priority**: almost always `low` for watch-later items unless the user signals urgency

Infer from the title/description if confident:

- Proxmox, Docker, Ansible, networking, self-hosting → `homelab`
- DevOps, CI/CD, cloud, platform engineering, certs → `learning`
- AI, machine learning, neural networks, LLMs → `learning`
- Secrets, Vault, enterprise security → `work-primary`
- MTB, cycling, coaching → `mtb`
- Communication, leadership, personal dev → `personal`

### 3. Draft the issue body

```markdown
## Story
As a [role], I want to watch "[title]" by [channel], so that [benefit inferred from description].

## Acceptance Criteria
- [ ] Watch https://www.youtube.com/watch?v={ID}
- [ ] Add key takeaways as a comment

## Context & Links
- Channel: [channel name]
- Duration: [duration]
- Description: [first 300–500 chars, truncated at sentence boundary]

> Add updates and blockers as comments, not edits to this body.
```

**Role guidance by domain:**

- `homelab` → "a homelab operator"
- `learning` → "an engineer upskilling in [topic]"
- `work-primary` → "a Vault team lead" or "an SRE"
- `personal` → "a [parent/director/coach] developing [skill]"

### 4. Create the GitHub Issue

```bash
gh issue create \
  --repo <routing.personal_kb_github> \
  --title "Watch: {title}" \
  --label "domain/{domain},priority/{priority}" \
  --body "{rendered body}"
```

Capture the returned URL and issue number.

### 5. Add to the correct GitHub Project

If `github_projects.<domain>` is set in `~/.config/ai-skills/local.json`, add the issue to that project:

```bash
gh project item-add {PROJECT_NUMBER} --owner {OWNER} --url {ISSUE_URL}
```

Otherwise skip project assignment.

### 6. Append to `~/Projects/personal/memex/Raw/_GitHub-Issues-log.jsonl`

```json
{"v":1,"record":"issue","when":"YYYY-MM-DD","issue_number":NNN,"title":"Watch: {title}","url":"{url}","repo":"${GITHUB_PERSONAL_USER}/memex","vault_task":null,"labels":["domain/{domain}","priority/low"],"notes":"YouTube watch item — {channel}"}
```

### 7. Append to `~/Projects/personal/memex/Raw/_task-index.jsonl`

```json
{"v":1,"system":"github","repo":"${GITHUB_PERSONAL_USER}/memex","instance":null,"id":"{NUMBER}","url":"{url}","title":"Watch: {title}","domain":"{domain}","project":"{Project}","status":"open","created":"YYYY-MM-DD","vault_ref":null}
```

### 8. Confirm to the user

Report:

- Issue number and URL as a markdown link
- Title, channel, duration
- Project it was added to

Example: "Created [#129 — Watch: MCP Tutorial by Christian Lempa](https://github.com/...) → HomeLab project, priority/low (19:22)."
