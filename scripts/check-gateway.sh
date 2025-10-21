#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") <host> [ip]

Ensures the HTTPS Gateway responds with HTTP 200 by using curl --resolve.
- host: FQDN routed through the Gateway (e.g. app.wminor.xyz)
- ip:   Optional. If omitted, terraform output -raw gateway_ip is used.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

HOST="$1"
IP="${2:-}"

if [[ -z "$IP" ]]; then
  if ! command -v terraform >/dev/null 2>&1; then
    echo "terraform command not found and no IP provided" >&2
    exit 1
  fi
  IP="$(terraform -chdir=infra/tf output -raw gateway_ip)"
fi

echo "Probing https://${HOST} via IP ${IP}"
curl --silent --show-error --fail --resolve "${HOST}:443:${IP}" "https://${HOST}/" | head -n 20
