---
version: 1.1.0
principles_version: 1.0.0
last_updated: 2026-08-14
updated_by: claude
---

# Pre-commit checks

Run checks **only on files you are modifying**. Do not run repo-wide formatters or linters as a side effect of an unrelated change — it pollutes the diff and steps on other people's in-flight work.

## Terraform

Before committing any `.tf` or `.tfvars` file:

```bash
# Format only the files in scope — not the whole repo
terraform fmt <file.tf>

# Or for a specific directory you own
terraform fmt <directory/>

# Never run this unless explicitly asked to clean up the whole repo
# terraform fmt -recursive
```

Check first with `terraform fmt -check <file>` to see if changes are needed before modifying. If the repo has a CI check that enforces fmt, fix it now rather than letting CI fail.

**The shared-repo rule**: If you're making a targeted change in a team repo and you notice other files are unformatted (e.g. from a teammate's recent commit), do *not* fix them in your PR. Flag it in a comment or a separate issue. Mixing formatting fixes with functional changes makes reviews harder and can conflict with in-flight work.

## Other languages and tools

Only run formatters/linters that are already configured in the repo. Check before running:

| Tool | Config signal | Scope |
| --- | --- | --- |
| `black` / `ruff` | `pyproject.toml`, `.ruff.toml`, `setup.cfg` | Modified `.py` files only |
| `shellcheck` | CI config, `Makefile` | Modified `.sh` files only |
| `yamllint` | `.yamllint`, CI config | Modified `.yml`/`.yaml` files only |
| `prettier` | `.prettierrc`, `package.json` | Modified files only |
| `markdownlint` | `.markdownlint.json`, or a pre-commit CI workflow that runs `markdownlint-cli2` | Modified `.md` files only |

If no config exists for a tool, do not run it. Do not install or introduce new formatters without asking.

## Before every commit — quick checklist

- [ ] No secrets, tokens, or credentials in staged files
- [ ] No debug output, `console.log`, or `print` left in production paths
- [ ] Commit message follows conventional format with ticket ref if applicable
- [ ] Pre-commit checks run on modified files
- [ ] Branch name matches repo convention (check recent branches if unsure)

**Pre-commit hook auto-fix recovery**: if a commit fails with "files were modified by this hook" (common with markdownlint, prettier, black, and similar auto-fixing hooks), the hook reformatted one or more staged files rather than just flagging them. Run `git diff --name-only` to see which files changed, `git add <those files>`, then retry the commit. Do not use `--no-verify` to skip the hook.
