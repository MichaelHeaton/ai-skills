---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-06-13
updated_by: claude
name: deep-review
description: Multi-lens code review that runs four sequential specialist passes — security, performance, architecture, and style — then produces a consolidated findings table ranked by severity. Use when you want more than a general review, need targeted coverage across dimensions, or say "deep review", "multi-pass review", "review for security and performance", "thorough review", "comprehensive code review", "check this for security issues and performance", or "specialist review". Complements /security-review (which does a focused security audit only) and /code-review (which reviews a diff at adjustable effort). Use deep-review when you want all four lenses in one pass.
---

# Deep Review

Run four sequential specialist passes over the target code, then merge findings into a single prioritised table.

The built-in `/security-review` covers security in depth for dedicated audits. This skill is for cross-cutting reviews where you want security *alongside* performance, architecture, and style in one session — without needing to invoke four separate commands.

---

## 0. Establish scope

Before running passes, confirm:

- **Target**: PR diff, branch, specific file(s), or current working tree?
- **Passes to run**: default is all four; the user can narrow (e.g. "skip style").
- **Depth**: quick (skim for obvious issues) or thorough (read logic in detail)?

If the target is a PR, read the diff now with `gh pr diff` or the GitHub MCP tools. If it's files, read them.

---

## 1. Security pass

Focus: vulnerabilities and trust boundary violations.

Check for:

- **Injection** — SQL, shell, LDAP, template, path traversal
- **Authentication / authorisation** — missing checks, privilege escalation, insecure defaults
- **Secrets and PII** — hardcoded credentials, tokens, keys committed to source
- **Dependency risk** — unpinned versions, known-vulnerable packages
- **Input validation** — missing bounds, type, or format checks at system boundaries
- **Output encoding** — XSS, open redirect, response header injection
- **Cryptography** — weak algorithms, insecure random, improper key handling

Severity scale: **Critical** (exploitable, no interaction) / **High** (exploitable with low effort) / **Medium** (requires attacker context) / **Low** (defence-in-depth)

---

## 2. Performance pass

Focus: code that will be slow or expensive at scale.

Check for:

- **Algorithmic complexity** — O(n²) or worse where O(n log n) is available; nested loops over large collections
- **Database / storage** — N+1 queries, missing indexes, unbounded result sets, SELECT *
- **Caching** — expensive computations or network calls repeated without memoisation
- **I/O patterns** — synchronous blocking in hot paths, large payloads serialised unnecessarily
- **Memory** — large allocations in loops, leaked resources, unbounded buffers
- **Concurrency** — lock contention, unnecessary serialisation, missing parallelism opportunities

Severity scale: **High** (measurable regression under normal load) / **Medium** (degraded at scale) / **Low** (micro-optimisation, negligible real-world impact)

---

## 3. Architecture pass

Focus: coupling, cohesion, and long-term maintainability.

Check for:

- **Coupling** — tight dependencies between unrelated modules; changes that force cascading edits elsewhere
- **Cohesion** — functions or classes doing more than one thing; mixed abstraction levels
- **Abstraction leaks** — implementation details escaping through public interfaces
- **Duplication** — copy-pasted logic that will diverge; failure to reuse existing utilities
- **Error handling** — swallowed exceptions, vague error messages, missing rollback logic
- **Test coverage** — untested happy path, no coverage of error branches, tests asserting implementation not behaviour
- **Scope creep** — changes that are larger than the stated purpose of the PR

Severity scale: **High** (makes future work materially harder) / **Medium** (technical debt that will compound) / **Low** (preference or style — no concrete future cost)

---

## 4. Style pass

Focus: readability and conventions.

Check for:

- **Naming** — misleading, abbreviated, or inconsistent names
- **Clarity** — logic that requires re-reading to understand; unnecessary cleverness
- **Comments** — missing explanation of *why* for non-obvious decisions; comments that restate code
- **Dead code** — unused variables, unreachable branches, stale TODO/FIXME
- **Consistency** — deviations from surrounding code style (formatting, patterns, idioms)

Severity scale: **Medium** (confuses future readers) / **Low** (preference)

---

## 5. Consolidated findings

Merge all findings from passes 1–4 into a single table, deduplicated and sorted by severity.

```
| Severity | Pass         | File / Location        | Finding                          | Recommendation                      |
|----------|--------------|------------------------|----------------------------------|-------------------------------------|
| Critical | Security     | auth/login.py:42       | Password compared with ==        | Use constant-time comparison        |
| High     | Performance  | api/search.py:88–102   | N+1 query inside result loop     | Prefetch related records            |
| Medium   | Architecture | utils/data.py          | CSV parse logic duplicated 3×    | Extract shared helper               |
| Low      | Style        | models/user.py:15      | Variable `d` is ambiguous        | Rename to `user_data`               |
```

After the table:

- **Summary**: one sentence per pass — what the pass found, or "no issues" if clean.
- **Top priority**: call out the one or two findings that most need attention before merge.
- **Skipped**: if any pass was omitted at the user's request, note it explicitly.

---

## 6. Next steps

Offer to:

- Open issues or PR comments for findings above a given severity threshold
- Fix specific findings in the working tree
- Re-run a single pass after fixes are applied

Don't do any of these automatically — wait for direction.
