#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [app-name]

Waits for an Argo CD application to reach Healthy/Synced status.
- app-name: optional, defaults to platform-root

Requires the argocd CLI to be logged in to the target Argo CD instance.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

APP="${1:-platform-root}"

if ! command -v argocd >/dev/null 2>&1; then
  echo "argocd CLI not found in PATH" >&2
  exit 1
fi

argocd app wait "${APP}" --health --sync
