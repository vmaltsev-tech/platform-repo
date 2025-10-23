#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [repo-url]

Updates Argo CD AppProject/Application manifests under platform/argo/ to use the provided Git repository.
If repo-url is omitted, the script falls back to the current Git remote "origin".
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

REPO_URL="${1:-}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${REPO_URL}" ]]; then
  if ! git -C "${REPO_ROOT}" remote get-url origin >/dev/null 2>&1; then
    echo "No origin remote found. Provide the repo URL explicitly." >&2
    exit 1
  fi
  REPO_URL="$(git -C "${REPO_ROOT}" remote get-url origin)"
fi

if [[ -z "${REPO_URL}" ]]; then
  echo "Repository URL must not be empty." >&2
  exit 1
fi

export REPO_URL

while IFS= read -r -d '' file; do
  rel_path="${file#${REPO_ROOT}/}"
  perl -0pi -e '
    my $url = $ENV{REPO_URL};
    s/(repoURL:\s*).+/$1$url/g;
    s/(sourceRepos:\s*\n\s*-\s*)\S+/$1$url/g;
  ' "$file"
  echo "Updated ${rel_path}"
done < <(find "${REPO_ROOT}/platform/argo" -name '*.yaml' -print0)

echo "repoURL set to: ${REPO_URL}"
