---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-14
updated_by: claude
name: mcp-auth-recovery
description: Diagnose and recover an MCP server namespace stuck in `needsAuth` or `error` state at the protocol layer — call the `mcp_auth` flow for that specific namespace, re-inspect its tools to confirm recovery, then retry the originally blocked tool call. Generic across MCP namespaces (Slack, GitHub, Linear, Grafana, Notion, Atlassian, and similar), not tied to any one integration. Trigger when a tool call to an MCP namespace fails or times out with an auth-shaped error, when that namespace's tool list is missing or degraded compared to what's normally available, or when a system message explicitly says a named MCP server "requires authentication" or "failed to connect." Distinct from gh-keyring-repair (broken local macOS Keychain credential store for the `gh` CLI) and gh-account-routing (correct CLI installed but the wrong `gh`/`glab` account is active) — those are CLI-layer, single-provider problems; this skill is the MCP protocol layer, any provider.
compatibility: Requires the `mcp_auth` tool/flow to be available in the current session. In non-interactive sessions (unattended cloud runs, scheduled tasks), `mcp_auth` may not be able to complete an OAuth flow — see Step 4 for the fallback.
---

# MCP Auth Recovery

An MCP server namespace can report `needsAuth` or `error` state independently of anything the CLI-layer skills cover. This skill diagnoses that specific failure and walks through recovery before retrying the blocked call.

## Distinction from adjacent skills

Three failure modes look similar (a call to a provider "isn't working") but sit at different layers:

- **`gh-keyring-repair`** — the local macOS Keychain-backed credential store for the `gh` CLI itself is broken. `gh auth status` reports logged in, but `gh auth token` returns empty. Pure CLI/OS problem, GitHub-specific.
- **`gh-account-routing`** — the `gh`/`glab` CLI is installed and working, but the wrong account is currently active for the repo being targeted. Not a broken credential, just the wrong one selected.
- **`mcp-auth-recovery`** (this skill) — an MCP server namespace, reached through the MCP protocol (not a CLI), itself reports `needsAuth` or `error`. This is unrelated to which CLI account is active or whether any keyring is healthy — an MCP namespace can be broken even when `gh` itself works perfectly, because the MCP connector's own OAuth/session state is what failed, not the CLI's.

This skill is **generic and namespace-agnostic**: it applies the same way to a Slack MCP connector, a GitHub MCP connector, Linear, Grafana, Notion, Atlassian, or any other MCP namespace — never assume it's GitHub-specific just because GitHub is one of the examples.

## Why this is its own skill

MCP namespace auth failures get misdiagnosed two ways without this skill: either as a CLI credential problem (leading someone to run `gh-keyring-repair` or `gh-account-routing` against a failure those skills can't see, since they only inspect the `gh`/`glab` CLI's own state) or as a permanent capability gap ("this tool doesn't exist here") when it's actually a recoverable session-auth state. Naming the failure correctly — an MCP namespace in `needsAuth`/`error` — points straight at the one fix that actually applies: `mcp_auth` for that namespace, not a keyring repair, not an account switch, and not giving up on the tool entirely.

## 1. Detect the failure

Watch for any of these signals pointing at a specific namespace:

- **A tool call to that namespace fails or times out** with an auth-shaped error (e.g. a `mcp_auth` call that itself times out, or a tool response indicating the session/token is invalid or expired).
- **The namespace's tool list is degraded or absent** — tools you expect from that server (`mcp__<namespace>__*`) don't show up in a normal listing, or `ToolSearch` returns nothing for a namespace that should have entries.
- **An explicit system message names the namespace** as requiring authentication or failing to connect. This session's own environment surfaces exactly this pattern — a system reminder listing MCP servers that "require authentication before their tools can be used," or servers that are "configured but failed to connect" with a connection error. Treat either of those reminder shapes as a direct, actionable signal naming which namespace(s) are affected — don't wait for a tool call to fail first if the reminder already told you.

Identify the specific namespace(s) affected before doing anything else — recovery is per-namespace, not a global reset.

### `needsAuth` vs `error` — both route through this skill

Don't spend time distinguishing these two states before acting — both mean "this namespace can't be used until something is fixed," and the recovery procedure (Steps 2-4) is identical for either:

- `needsAuth` typically means the namespace has never been authorized, or a token expired and needs a fresh OAuth grant.
- `error` (e.g. "connection closed") typically means the namespace was authorized but the live connection dropped or the server crashed.

The distinction matters only if Step 2's recovery fails — an `error` state that doesn't clear after `mcp_auth` may indicate the server itself is down rather than an auth problem, which is useful context to pass along when reporting to the user in Step 5.

## 2. Recover: call `mcp_auth` for that namespace

Invoke the `mcp_auth` tool/flow scoped to the specific namespace that's stuck, not every namespace in the session. If the environment exposes an interactive `/mcp` command or `claude mcp` CLI instead of a direct `mcp_auth` tool, use whichever mechanism is actually available in the current session.

**Do not broaden this into re-authenticating every connected MCP server** just because one is down — that wastes the user's time re-approving connectors that are already working fine.

## 3. Re-inspect tools to confirm recovery — before retrying anything

Once `mcp_auth` reports success (or you'd otherwise expect the namespace to be healthy again), confirm it actually recovered before touching the originally blocked call:

- Re-run `ToolSearch` for that namespace's tools (or re-check the tool listing) and confirm the expected tools are now present and no longer flagged as deferred/unauthenticated.
- If the namespace exposes a cheap, side-effect-free call (a "who am I" / list-connectors / status-style tool), prefer that over the original blocked call as the recovery check.

**Do not skip this confirmation step and retry the original call directly.** A `mcp_auth` call can appear to complete without actually restoring the namespace (partial token refresh, scope mismatch, silent failure) — retrying blind risks hitting the exact same failure again, or worse, retrying into a different error that looks like the original one and gets misdiagnosed.

## 4. Retry the originally blocked tool call

Only after Step 3 confirms the namespace is healthy, retry the specific tool call that was blocked. Use the same arguments/intent as the original attempt — this step is a retry, not a new action requiring re-derivation of what the user wanted.

If the retried call fails again with the same auth-shaped error, treat that as a new, distinct failure — return to Step 1 rather than looping Step 2 against the same recovery attempt.

## 5. When `mcp_auth` times out or recovery doesn't work

**This is expected in non-interactive sessions** — unattended cloud runs, scheduled tasks, and similar environments often cannot complete an OAuth flow because there's no interactive browser/approval step available.

When this happens:

- **Report to the user** which specific MCP server needs authorization and how to fix it: for a `claude.ai` connector, that's the claude.ai connector settings page; for other MCP servers, that's `claude mcp` or `/mcp` run in an interactive session.
- **Name the exact namespace(s)** affected — don't give a generic "some tools aren't working" message when the failing server(s) are already known from Step 1.
- **Do not loop retrying** `mcp_auth` or the blocked call hoping it resolves itself. A non-interactive session cannot complete the OAuth handshake no matter how many times it's attempted — repeated retries burn time and tool calls without changing the outcome.
- **Do not ask the user for tokens, API keys, or callback URLs** to work around the missing interactive flow — that bypasses the connector's own auth mechanism and is out of scope for this skill (and generally unsafe).

## Worked example

A tool call to `mcp__linear__linear_create_issue` times out. Applying this skill:

1. **Detect** — the timeout alone is ambiguous, but a system reminder in the same turn lists `linear` under "configured but failed to connect (CONNECTION_CLOSED)." That names the namespace: `linear`.
2. **Recover** — call `mcp_auth` scoped to `linear` (or `/mcp` if that's what the session exposes). Suppose it reports success.
3. **Confirm** — re-run `ToolSearch` for `linear` tools. If they now appear as callable (not deferred, not absent), recovery is confirmed. If `ToolSearch` still shows nothing for `linear`, recovery did not actually work — go to Step 5, don't retry yet.
4. **Retry** — once confirmed, call `mcp__linear__linear_create_issue` again with the original arguments.
5. **If `mcp_auth` had timed out instead** (common in a non-interactive scheduled-task run) — report: "The Linear MCP connector needs authorization. Since this is a non-interactive session, please authorize it via claude.ai connector settings (or `claude mcp` / `/mcp` in an interactive session), then re-run this task." Stop there — don't keep calling `mcp_auth` against `linear` hoping a retry changes the outcome.

## Common mistakes to avoid

- **Retrying the blocked call immediately after `mcp_auth` returns**, without the Step 3 confirmation — this can silently repeat the original failure or mask a partial recovery.
- **Treating this as a `gh`/CLI problem** and routing to `gh-keyring-repair` or `gh-account-routing` — those skills inspect CLI-layer state (Keychain, active `gh auth status` account) and have no visibility into MCP protocol-layer auth state; running them against an MCP namespace failure wastes time and fixes nothing.
- **Looping `mcp_auth` in a non-interactive session** after it has already timed out once — if the environment can't complete an OAuth handshake, repeating the attempt doesn't change that.
- **Re-authenticating every connected namespace** when only one is actually broken — scope recovery to the specific namespace identified in Step 1.

## Example namespaces this applies to

This skill is not tied to any single provider. Concrete examples of MCP namespaces it recovers the same way:

- **Slack** — an MCP Slack connector reporting `needsAuth` blocks `slack_send_message`, `slack_read_channel`, etc.
- **GitHub** — an MCP GitHub connector (distinct from the `gh` CLI) reporting `error` blocks issue/PR tools exposed via MCP.
- **Linear** — a Linear MCP connector failing to connect blocks ticket read/write tools for that namespace.
- **Grafana** — a Grafana MCP connector in `needsAuth` blocks dashboard/query tools.
- **Notion** — a Notion MCP connector reporting connection closed blocks search/page tools.

The same three-step recovery (call `mcp_auth` for the namespace, confirm via tool re-inspection, retry) applies regardless of which of these — or any other MCP namespace — is affected.
