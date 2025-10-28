#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [host] [ip]

Ensures the HTTPS Gateway responds with HTTP 2xx using curl --resolve.
- host: Optional FQDN routed through the Gateway (defaults to terraform output -raw host)
- ip:   Optional. If omitted, terraform output -raw gateway_ip is used.
Env:
- CURL_MAX_TIME (default: 20)
- CURL_CONNECT_TIMEOUT (default: 5)
- FOLLOW_REDIRECTS (default: 1, use 0 to disable)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 2 ]]; then
  usage
  exit 64  # EX_USAGE
fi

# Make terraform path relative to this script
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
TF_DIR="${SCRIPT_DIR}/infra/tf"

HOST="${1:-}"
IP="${2:-}"

if [[ -z "$HOST" ]]; then
  if ! command -v terraform >/dev/null 2>&1; then
    echo "terraform command not found and no host provided" >&2
    exit 1
  fi
  if ! HOST="$(terraform -chdir="${TF_DIR}" output -raw host)"; then
    echo "failed to read terraform output 'host'" >&2
    exit 1
  fi
fi

if [[ -z "$IP" ]]; then
  if ! command -v terraform >/dev/null 2>&1; then
    echo "terraform command not found and no IP provided" >&2
    exit 1
  fi
  if ! IP="$(terraform -chdir="${TF_DIR}" output -raw gateway_ip)"; then
    echo "failed to read terraform output 'gateway_ip'" >&2
    exit 1
  fi
fi

# Wrap IPv6 in [] for --resolve
if [[ "$IP" == *:* && "$IP" != [*] ]]; then
  IP="[$IP]"
fi

MAX_TIME="${CURL_MAX_TIME:-20}"
CONNECT_TIMEOUT="${CURL_CONNECT_TIMEOUT:-5}"
FOLLOW_REDIRECTS="${FOLLOW_REDIRECTS:-1}"

echo "Probing https://${HOST} via IP ${IP}"
TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT

# Build curl args
curl_args=(
  --silent --show-error
  --resolve "${HOST}:443:${IP}"
  --write-out '%{http_code}'
  --output "${TMP}"
  --connect-timeout "${CONNECT_TIMEOUT}"
  --max-time "${MAX_TIME}"
  --proto '=https'
  "https://${HOST}/"
)

# Enable redirects if desired
if [[ "${FOLLOW_REDIRECTS}" == "1" ]]; then
  curl_args=( -L "${curl_args[@]}" )
fi

# Do NOT let set -e kill the script on curl failure; we want to capture http_code "000"
set +e
STATUS="$(curl "${curl_args[@]}")"
curl_rc=$?
set -e

# If curl failed at transport level, print reason and body (if any)
if (( curl_rc != 0 )); then
  echo "curl failed (rc=${curl_rc}), http_code=${STATUS:-000}" >&2
  [[ -s "${TMP}" ]] && { echo "--- body ---" >&2; cat "${TMP}" >&2; }
  exit 1
fi

# Accept any 2xx
if [[ ! "${STATUS}" =~ ^2[0-9]{2}$ ]]; then
  echo "Unexpected status code: ${STATUS}" >&2
  [[ -s "${TMP}" ]] && { echo "--- body ---" >&2; cat "${TMP}" >&2; }
  exit 1
fi

cat "${TMP}"
echo "HTTPS Gateway check succeeded with status code: ${STATUS}"