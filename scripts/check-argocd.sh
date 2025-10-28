#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [app-name]

Waits for an Argo CD application to reach Healthy/Synced status.
- app-name: optional, defaults to platform-root
- set ARGOCD_WAIT_TIMEOUT (seconds) to override the default 600s timeout

Requires the argocd CLI to be logged in to the target Argo CD instance.
EOF
}

# help
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# fail on extra args
if (( $# > 1 )); then
  echo "too many arguments" >&2
  usage
  exit 2
fi

APP="${1:-platform-root}"
TIMEOUT="${ARGOCD_WAIT_TIMEOUT:-600}"

# numeric timeout check
if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
  echo "ARGOCD_WAIT_TIMEOUT must be an integer (got: $TIMEOUT)" >&2
  exit 2
fi

if ! command -v argocd >/dev/null 2>&1; then
  echo "argocd CLI not found in PATH" >&2
  exit 127
fi

argocd app wait "$APP" --health --sync --timeout "$TIMEOUT"
