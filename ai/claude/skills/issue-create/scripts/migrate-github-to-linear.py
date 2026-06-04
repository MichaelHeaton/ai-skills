#!/usr/bin/env python3
"""
migrate-github-to-linear.py

For each open GitHub issue in a repo:
  1. Creates a new Linear issue in the target project
  2. Closes the GitHub issue (which also closes the old synced Linear duplicate)

The new Linear issue is unlinked from GitHub — it stays open permanently.

Reads:
  - Linear API key from Keychain (service: claude-mcp-linear, account: claude-code)
  - GitHub token via: gh auth token --user <GITHUB_USER>

Usage:
  python3 migrate-github-to-linear.py --dry-run
  python3 migrate-github-to-linear.py

  Override defaults via env:
    GITHUB_REPO=MichaelHeaton/memex LINEAR_PROJECT="Personal" python3 migrate-github-to-linear.py
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request

GITHUB_REPO    = os.environ.get("GITHUB_REPO",    "MichaelHeaton/claude-skills")
GITHUB_USER    = os.environ.get("GITHUB_USER",    "MichaelHeaton")
LINEAR_TEAM    = os.environ.get("LINEAR_TEAM",    "SpecterRealm")
LINEAR_PROJECT = os.environ.get("LINEAR_PROJECT", "AI Skills")
LOG_FILE       = os.path.expanduser(f"~/migrate-{GITHUB_REPO.replace('/', '-')}.jsonl")

PRIORITY_MAP = {
    "priority/high":   2,
    "priority/medium": 3,
    "priority/low":    4,
}

# ── credentials ──────────────────────────────────────────────────────────────

def get_linear_token():
    r = subprocess.run(
        ["security", "find-generic-password",
         "-s", "claude-mcp-linear", "-a", "claude-code", "-w"],
        capture_output=True, text=True
    )
    t = r.stdout.strip()
    if not t:
        sys.exit("ERROR: Linear API key not found in Keychain (service: claude-mcp-linear)")
    return t

def get_github_token(user):
    r = subprocess.run(["gh", "auth", "token", "--user", user],
                       capture_output=True, text=True)
    t = r.stdout.strip()
    if not t:
        sys.exit(f"ERROR: GitHub token not found for user {user}")
    return t

# ── Linear GraphQL ────────────────────────────────────────────────────────────

def linear_gql(token, query, variables=None):
    payload = json.dumps({"query": query, "variables": variables or {}}).encode()
    req = urllib.request.Request(
        "https://api.linear.app/graphql",
        data=payload,
        headers={"Authorization": token, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())
    if "errors" in data:
        raise RuntimeError(f"Linear API error: {data['errors']}")
    return data["data"]

def resolve_team(token, name):
    data = linear_gql(token, "query { teams { nodes { id name } } }")
    for t in data["teams"]["nodes"]:
        if t["name"].lower() == name.lower():
            return t["id"]
    available = [t["name"] for t in data["teams"]["nodes"]]
    sys.exit(f"ERROR: Linear team '{name}' not found. Available: {available}")

def resolve_project(token, team_id, name):
    data = linear_gql(token, """
        query($id: String!) { team(id: $id) { projects { nodes { id name } } } }
    """, {"id": team_id})
    for p in data["team"]["projects"]["nodes"]:
        if p["name"].lower() == name.lower():
            return p["id"]
    available = [p["name"] for p in data["team"]["projects"]["nodes"]]
    sys.exit(f"ERROR: Linear project '{name}' not found. Available: {available}")

def create_linear_issue(token, team_id, project_id, title, description, priority):
    data = linear_gql(token, """
        mutation Create($input: IssueCreateInput!) {
            issueCreate(input: $input) {
                success
                issue { id identifier url }
            }
        }
    """, {"input": {
        "teamId":      team_id,
        "projectId":   project_id,
        "title":       title,
        "description": description,
        "priority":    priority,
    }})
    if not data["issueCreate"]["success"]:
        raise RuntimeError("issueCreate returned success=false")
    return data["issueCreate"]["issue"]

# ── GitHub ────────────────────────────────────────────────────────────────────

def fetch_github_issues(gh_token, repo):
    env = {**os.environ, "GH_TOKEN": gh_token}
    r = subprocess.run(
        ["gh", "issue", "list", "--repo", repo,
         "--state", "open",
         "--json", "number,title,body,labels,url",
         "--limit", "1000"],
        capture_output=True, text=True, env=env, check=True
    )
    return json.loads(r.stdout)

def close_github_issue(gh_token, repo, number, linear_url):
    env = {**os.environ, "GH_TOKEN": gh_token}
    subprocess.run(
        ["gh", "issue", "close", str(number),
         "--repo", repo,
         "--comment", f"Migrated to Linear: {linear_url}\nClosing GitHub issue — work continues in Linear.",
         "--reason", "not planned"],
        capture_output=True, env=env, check=True
    )

# ── main ──────────────────────────────────────────────────────────────────────

def build_description(issue):
    label_names = [l["name"] for l in issue.get("labels", [])]
    body = (issue.get("body") or "").strip()
    parts = [f"*Migrated from GitHub: {issue['url']}*"]
    if body:
        parts += ["", body]
    if label_names:
        parts += ["", f"**GitHub labels:** {', '.join(label_names)}"]
    return "\n".join(parts)

def detect_priority(issue):
    label_names = [l["name"] for l in issue.get("labels", [])]
    for label in label_names:
        if label in PRIORITY_MAP:
            return PRIORITY_MAP[label]
    return 3  # medium default

def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview without creating or closing anything")
    args = parser.parse_args()

    print(f"Repo:    {GITHUB_REPO}")
    print(f"Team:    {LINEAR_TEAM}")
    print(f"Project: {LINEAR_PROJECT}")
    print(f"Log:     {LOG_FILE}")
    if args.dry_run:
        print("Mode:    DRY RUN\n")
    else:
        print("Mode:    LIVE\n")

    print("Reading credentials...")
    linear_token = get_linear_token()
    gh_token     = get_github_token(GITHUB_USER)

    print("Resolving Linear IDs...")
    team_id    = resolve_team(linear_token, LINEAR_TEAM)
    project_id = resolve_project(linear_token, team_id, LINEAR_PROJECT)
    print(f"  ✓ team={team_id}  project={project_id}")

    print(f"\nFetching open issues from {GITHUB_REPO}...")
    issues = fetch_github_issues(gh_token, GITHUB_REPO)
    print(f"  Found {len(issues)} open issues\n")

    if args.dry_run:
        print(f"Would create {len(issues)} Linear issues and close {len(issues)} GitHub issues.")
        print("\nFirst 5 preview:")
        for issue in issues[:5]:
            pri = detect_priority(issue)
            print(f"  #{issue['number']} [p{pri}] {issue['title'][:70]}")
        if len(issues) > 5:
            print(f"  ... and {len(issues) - 5} more")
        return

    migrated = errors = 0
    total = len(issues)

    for i, issue in enumerate(issues, 1):
        num   = issue["number"]
        title = issue["title"]
        try:
            linear_issue = create_linear_issue(
                linear_token, team_id, project_id,
                title,
                build_description(issue),
                detect_priority(issue),
            )
            lid  = linear_issue["identifier"]
            lurl = linear_issue["url"]

            close_github_issue(gh_token, GITHUB_REPO, num, lurl)

            record = {
                "gh_number": num, "gh_url": issue["url"],
                "linear_id": lid, "linear_url": lurl,
                "title": title, "status": "migrated",
            }
            migrated += 1
            print(f"  [{i}/{total}] ✓ #{num} → {lid}  {title[:60]}")

        except Exception as e:
            record = {"gh_number": num, "title": title, "status": "error", "error": str(e)}
            errors += 1
            print(f"  [{i}/{total}] ✗ #{num} ERROR: {e}")

        with open(LOG_FILE, "a") as f:
            f.write(json.dumps(record) + "\n")

        time.sleep(0.4)

    print(f"\n{'─'*50}")
    print(f"Done.  ✓ {migrated} migrated   ✗ {errors} errors")
    print(f"Log:   {LOG_FILE}")
    if errors:
        print(f"\nRetry errors with:")
        print(f"  python3 {__file__}  (re-run skips already-closed issues)")

if __name__ == "__main__":
    main()
