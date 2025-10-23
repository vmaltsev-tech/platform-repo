#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [host]

Updates Gateway manifests to use the provided host.
If host is omitted, the value is read from terraform output -raw host.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

HOST="${1:-}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${HOST}" ]]; then
  if ! command -v terraform >/dev/null 2>&1; then
    echo "terraform command not found and no host provided" >&2
    exit 1
  fi
  HOST="$(terraform -chdir="${REPO_ROOT}/infra/tf" output -raw host)"
fi

export GATEWAY_HOST="${HOST}"

perl -0pi -e '
  my $host = $ENV{GATEWAY_HOST};
  s/(hostnames:\s*\n\s*-\s*).+/$1$host/g;
' "${REPO_ROOT}/infra/apps/gateway/httproute.yaml"

perl -0pi -e '
  my $host = $ENV{GATEWAY_HOST};
  s/(domains:\s*\n\s*-\s*).+/$1$host/g;
' "${REPO_ROOT}/infra/apps/gateway/cert.yaml"

echo "Gateway manifests now reference host: ${HOST}"
