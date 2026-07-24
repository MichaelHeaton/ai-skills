---
version: 1.0.0
principles_version: 1.0.0
last_updated: 2026-06-10
updated_by: human
---

# Test case frontmatter fields

Add these five fields after the `tags:` line in the frontmatter created by `add_test_case.py`:

```yaml
miss_reasons: []             # one or more: missing-doc | stale-doc | context-gap | correct | user-education | operational-request | wrong-team | team-only
question_type: ""            # how-to | troubleshooting | pr-review | onboarding | access-request | roadmap | routing
product_area: ""             # vault-policies | authentication | kv2 | approle | onboarding | routing | general
resolution_source: ""        # sherlock | team | unresolved
team_reply_vs_sherlock: ""   # confirmed | expanded | corrected | no-reply | na
```
