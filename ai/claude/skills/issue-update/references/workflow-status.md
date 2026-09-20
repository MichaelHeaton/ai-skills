# Workflow status (board Status / Jira transition)

Progress comments are not enough. When work on a ticket **starts**, **pauses**, or **finishes**, update the **workflow status** in the planning surface — not only the task-index `open`/`closed` bit.

## What “status” means

| System | Field | Values (typical) |
| --- | --- | --- |
| **HomeLab Project** ([project 15](https://github.com/users/MichaelHeaton/projects/15)) | Project **Status** | Icebox → Groomed → **In Progress** → Done |
| **Jira** | Workflow transition | e.g. To Do → In Progress → Done (use `jira_get_transitions` — never guess IDs) |
| **GitHub issue `state`** | open / closed | Still required on finish; Project **Done** usually follows close |

Do **not** treat a progress comment alone as a status update. Focus view filters on Project Status = `In Progress`.

## When agents must update Status

| Moment | Action |
| --- | --- |
| **Start** implementing / focusing a ticket | Set Status → **In Progress** (and capability **parent** to In Progress if this is a child leaf) |
| **Park** mid-work (switching tickets, end of session without finish) | Leave **In Progress** if still the active Focus item; otherwise set **Groomed** and comment `Next action: …` |
| **Finish** (all ACs done) | Close issue (→ Done) via normal close path; comment completion summary |
| **Create** a ticket you will work **in this session** | After create, set Status → **In Progress** (do not leave new work on Icebox while coding) |
| **Create** for later | Leave Icebox (auto-add) or set **Groomed** if pullable |

Soft WIP: only the **active leaf** (+ its capability parent when using HomeLab parents) should be **In Progress**. Do not pile every related ticket into In Progress.

## HomeLab Project — commands

Project number **15**, owner **MichaelHeaton**. Field name is exactly `Status`.

```bash
# Start / resume
gh project item-edit 15 --owner MichaelHeaton \
  --url "https://github.com/MichaelHeaton/homelab-infra/issues/{N}" \
  --field Status --value "In Progress"

# Park as pullable (not actively driving)
gh project item-edit 15 --owner MichaelHeaton \
  --url "https://github.com/MichaelHeaton/homelab-infra/issues/{N}" \
  --field Status --value "Groomed"

# Ensure item is on the board (auto-add usually covers open issues)
gh project item-add 15 --owner MichaelHeaton \
  --url "https://github.com/MichaelHeaton/homelab-infra/issues/{N}"
```

If `item-edit` fails because the issue is not on the project, `item-add` first, then set Status.

Other personal repos that use a GitHub Project with a Status single-select: same `gh project item-edit` pattern with that project’s number/owner — look up field option names with `gh project field-list <n> --owner …`.

## Jira

```text
jira_get_transitions → pick "In Progress" (or equivalent) → jira_transition_issue
```

On finish: comment → transition to Done/Closed (see skill close path + `ticket-close-sequence`).

## Confirm

After a Status change, say so in the user-facing reply, e.g. `→ #1240 Status: In Progress`.
