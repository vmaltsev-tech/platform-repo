#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [repo-url]

Updates Argo CD AppProject/Application manifests under platform/argo/ to use the provided Git repository.
If repo-url is omitted, current Git remote "origin" is used.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage; exit 0
fi

REPO_URL="${1:-}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"
ARGO_DIR="${REPO_ROOT}/platform/argo"

# Derive from git remote if not supplied
if [[ -z "${REPO_URL}" ]]; then
  if ! git -C "${REPO_ROOT}" remote get-url origin >/dev/null 2>&1; then
    echo "No origin remote found. Provide the repo URL explicitly." >&2
    exit 1
  fi
  REPO_URL="$(git -C "${REPO_ROOT}" remote get-url origin)"
fi

# Basic URL sanity (https or ssh)
if ! [[ "${REPO_URL}" =~ ^(https://|ssh://|git@)[^[:space:]]+$ ]]; then
  echo "Repository URL looks invalid: '${REPO_URL}'" >&2
  exit 64
fi

if [[ ! -d "${ARGO_DIR}" ]]; then
  echo "Directory not found: ${ARGO_DIR}" >&2
  exit 1
fi

export REPO_URL

changed=0
found_files=0
# -print0 + read -d '' корректно обрабатывают пробелы
while IFS= read -r -d '' file; do
  found_files=1
  rel_path="${file#${REPO_ROOT}/}"
  cp -f -- "$file" "${file}.bak"

  # 1) Жёстко меняем repoURL (строка вида 'repoURL: ...', игнорируя комментарии)
  # 2) Полностью перезаписываем массив sourceRepos одним элементом (наш URL)
  perl -0777 -pe '
    my $url = $ENV{REPO_URL};

    # repoURL: value
    s/^( \s* repoURL \s* : \s* ).*$/\1$url/mx;

    # sourceRepos:
    #   - old1
    #   - old2
    # -> sourceRepos:
    #      - <url>
    s/^( \s* sourceRepos \s* : \s* \n ) (?: (?:\s* - \s* .*\n)+ ) /$1  - $url\n/mx;
  ' -i -- "$file"

  if ! diff -q -- "$file.bak" "$file" >/dev/null 2>&1; then
    echo "Updated ${rel_path}"
    changed=1
  else
    echo "No change ${rel_path}"
    rm -f -- "$file.bak"
  fi
done < <(find "${ARGO_DIR}" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

if [[ "${found_files}" -eq 0 ]]; then
  echo "No YAML files under ${ARGO_DIR}" >&2
  exit 1
fi

if [[ "${changed}" -eq 0 ]]; then
  echo "No files updated. Patterns may not match your manifests." >&2
  exit 1
fi

echo "repoURL set to: ${REPO_URL}"
