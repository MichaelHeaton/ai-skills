#!/usr/bin/env bash
# Discover AI-documentable components in a repo.
# Usage: discover-components.sh [repo-path]
# Output: one line per component — TYPE:PATH:HAS_AGENT_MD

set -euo pipefail

REPO="${1:-.}"
cd "$REPO" || { echo "ERROR: cannot cd to $REPO" >&2; exit 1; }

has_agent_md() {
  local path="$1"
  [[ -f "$path/AGENT.md" ]] && echo "yes" || echo "no"
}

# Ansible roles — dirs under roles/ with a tasks/main.yml or tasks/main.yaml
if [[ -d "roles" ]]; then
  while IFS= read -r -d '' role_dir; do
    if [[ -f "$role_dir/tasks/main.yml" || -f "$role_dir/tasks/main.yaml" ]]; then
      echo "ansible-role:${role_dir}:$(has_agent_md "$role_dir")"
    fi
  done < <(find roles -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
fi

# Ansible playbooks directory
if [[ -d "playbooks" ]]; then
  echo "ansible-playbooks:playbooks:$(has_agent_md "playbooks")"
fi

# Terraform modules — dirs under modules/ with a main.tf
if [[ -d "modules" ]]; then
  while IFS= read -r -d '' mod_dir; do
    if [[ -f "$mod_dir/main.tf" ]]; then
      echo "terraform-module:${mod_dir}:$(has_agent_md "$mod_dir")"
    fi
  done < <(find modules -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
fi

# Helm charts — dirs under charts/ with a Chart.yaml
if [[ -d "charts" ]]; then
  while IFS= read -r -d '' chart_dir; do
    if [[ -f "$chart_dir/Chart.yaml" ]]; then
      echo "helm-chart:${chart_dir}:$(has_agent_md "$chart_dir")"
    fi
  done < <(find charts -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
fi

# Terraform roots — main.tf nested 2+ levels deep outside modules/ (common in infra
# repos for per-environment deployments, e.g. networking_infra/prod_va6/main.tf).
# mindepth 3 = dir depth >= 2, so first-level dirs stay with the generic README check
# below and don't get double-reported. maxdepth bounds the recursion cost.
while IFS= read -r -d '' tf_file; do
  tf_dir=$(dirname "$tf_file")
  echo "terraform-root:${tf_dir#./}:$(has_agent_md "$tf_dir")"
done < <(find . -mindepth 3 -maxdepth 6 -type f -name main.tf \
            -not -path '*/.*/*' \
            -not -path './modules/*' \
            -not -path './node_modules/*' \
            -not -path './vendor/*' \
            -print0 2>/dev/null | sort -z)

# Generic — first-level subdirs with a README.md not already caught above
# Excludes known non-component dirs and hidden dirs
SKIP_RE="^(roles|modules|charts|playbooks|node_modules|vendor|\.git|\.github|\.claude|\.cursor)$"
while IFS= read -r -d '' sub_dir; do
  dir_name=$(basename "$sub_dir")
  if echo "$dir_name" | grep -qE "$SKIP_RE"; then
    continue
  fi
  if [[ -f "$sub_dir/README.md" ]]; then
    echo "generic:${sub_dir}:$(has_agent_md "$sub_dir")"
  fi
done < <(find . -mindepth 1 -maxdepth 1 -type d -not -name '.*' -print0 2>/dev/null | sort -z)
