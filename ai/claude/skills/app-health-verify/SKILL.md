---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-09-11
updated_by: claude
name: app-health-verify
description: Run a layered functional health check on a service users report as broken, going past HTTP/blackbox status into response-body content, database health, a real auth-flow test, and background-job/worker signals. Use when a user says a service is "acting weird", "broken", "erroring", or "not working" despite monitoring or a status page showing green, when an HTTP 200 needs confirming as a genuinely healthy response rather than an error payload wrapped in a 200, or when asked to "check if X is actually working", "do a deeper health check", "the probe is green but users report errors", or "verify app health, not just uptime". Complements `infra-state-verify`, which gates claims that a service is *deployed/live* at all behind a ground-truth check — this skill assumes that's already established (or isn't in question) and checks whether the running service is *functionally healthy* underneath a green HTTP status. Each layer degrades gracefully when it needs secret material a session doesn't have — skip that layer explicitly and say so rather than treating the whole check as blocked.
compatibility: Any repo with HTTP access to the service, plus optional database/queue credentials for deeper layers — degrades gracefully without them.
---

# App Health Verify

An HTTP 200 proves the endpoint responded. It does not prove the service is healthy — a crashed database connection, a failed auth dependency, or a stuck worker queue can all sit quietly behind a green status code. The motivating incident: a service returned HTTP 200 with a GraphQL error payload in the response body, caused by a SQLite "database is locked" error, and no blackbox probe caught it because none of them read the body.

**Boundary with `infra-state-verify`**: that skill answers "is this actually deployed/running, or just declared in code" — the gate before trusting *any* live-state claim. This skill assumes the deployed/running question is settled (or isn't what's being asked) and goes one level deeper: given that the service is up and probably returning 200, is it *functionally* working? Run `infra-state-verify` first if deployment status itself is in doubt; run this skill once you know it's up and need to know if it's lying about being healthy.

## When to run this

- A user reports a service is broken, erroring, or behaving strangely, but the status page, blackbox probe, or `curl` shows 200/green
- Before telling a user "it's up" based only on a status code check
- After an incident where the root cause was hidden below the HTTP layer (a DB lock, an auth dependency outage, a stalled queue)

## The five layers

Run layers in order. Each layer's finding stands on its own — don't let a passing earlier layer suppress checking a later one, and don't let a layer you can't run (see degrade-gracefully rule below) block the layers you can.

### Layer 1 — Basic HTTP/blackbox status (reference, don't repeat)

This is `infra-state-verify`'s territory: confirming the service actually responds and, for public-facing production infra, that the claim is backed by a real check rather than an assumption. If that hasn't been established yet, run `infra-state-verify`'s checks first. `infra-state-verify` itself hands off to this skill for exactly this reason — its own "green probe doesn't confirm application-level health" note points here for the full layered procedure, rather than trying to own body/DB/auth checks itself. Once a response is confirmed, move to Layer 2 — a status code alone is not a health check.

### Layer 2 — Response-body inspection

A 200 status with an error payload in the body is a real failure, not a healthy response. Read the actual content:

- For JSON/REST: check for an `error`, `errors`, or non-2xx-style status field embedded in the body, not just the transport status code
- For GraphQL: a GraphQL error can legally ride inside a 200 response — check the `errors` array in the payload, not the HTTP status
- For HTML: check for an error page, stack trace, or maintenance banner rendered inside a 200 response
- Compare against a known-good response shape when one exists (a schema, a previous healthy capture) rather than eyeballing shape alone

**This is the layer the motivating incident lived in** — the SQLite lock surfaced as a GraphQL error inside a 200, invisible to anything checking status code only.

### Layer 3 — Database health

Check for connection, lock, and query-count signals where a check can reasonably reach them:

- **App-exposed health endpoint**: many services expose `/health` or `/healthz` with a DB sub-check (connection pool status, last successful query, lock state) — check this first since it needs no direct DB credentials
- **Direct query** (if credentials are available): a lightweight query (`SELECT 1`, a row count on a known table) confirms the connection is live and not blocked; for SQLite specifically, a "database is locked" error on a trivial query is the signature of the motivating incident
- **Query-count/latency signal**: a sudden drop to near-zero successful queries, or a spike in query latency, on a dashboard/metrics source indicates the app is up but the DB layer underneath it is not

### Layer 4 — Auth-flow test

Confirm a real (or test) auth flow actually *completes* — not just that the login page renders:

- Exercise the full flow: submit credentials (test account, not a real user's), follow the redirect, confirm a valid session token/cookie comes back
- A login page returning 200 is Layer 1/2 territory again — it says nothing about whether the backend auth service, token issuer, or session store behind it is actually working
- If no test credentials are available, note the gap explicitly (see degrade-gracefully rule) rather than treating "the login page loads" as a substitute finding

### Layer 5 — Background job / worker signals

Confirm queued work is actually processing, not just accepted into a queue:

- Check a queue depth metric over time — a queue that only grows, never drains, means jobs are stuck, not "queued and pending" as usual
- Check for a recent successful job completion timestamp, not just "workers are running" (a worker process can be alive and still failing every job it picks up)
- Check worker error/retry rates for a spike, which indicates jobs are being attempted and failing rather than silently succeeding

## Degrade gracefully — never dead-end on missing secrets

When a layer needs secret material (DB credentials, an API key, a real user auth token) that the current session doesn't have because a security control blocks access to it:

1. **Skip that specific layer explicitly** — say which layer was skipped and why (e.g. "Layer 3 direct-query check skipped: no DB credentials in this session")
2. **Substitute a lower-privilege signal for that layer where one exists** — an app-exposed health endpoint instead of a direct DB query, a login-page-reachability check instead of a full auth-flow test, a public queue-depth dashboard instead of direct broker access
3. **Still run every other layer** — a blocked layer is not a reason to report the whole health check as un-runnable; report findings from the layers that did run, and name the gap in the layers that didn't

This mirrors `infra-state-verify`'s own security-controls fallback: substitute a check that avoids the credential rather than stopping the check entirely, and document which check actually ran in place of the blocked one.

## Reporting the result

Name which layers ran, which were skipped and why, and what each one found — don't collapse the result to a single "healthy"/"broken" verdict without the supporting layer detail. A user acting on the report should be able to see exactly what was and wasn't checked.

**Bad** (collapses the layers, hides what was actually checked):

> The service is healthy — got a 200 back.

**Good** (names each layer and its outcome):

> Layer 1 (HTTP): 200 OK. Layer 2 (body): GraphQL `errors` array present — "database is locked". Layer 3 (DB): direct query timed out with a lock error, confirming Layer 2. Layer 4 (auth): skipped, no test credentials in this session — substituted login-page reachability, which loads fine but doesn't confirm the flow completes. Layer 5 (workers): queue depth flat at 0, no stuck jobs.
>
> Root cause is the DB lock in Layer 3, not an infra/deployment problem — service is up and reachable, just functionally broken underneath.
