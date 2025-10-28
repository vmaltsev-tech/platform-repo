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
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"

if [[ -z "${HOST}" ]]; then
  if ! command -v terraform >/dev/null 2>&1; then
    echo "terraform command not found and no host provided" >&2
    exit 1
  fi
  HOST="$(terraform -chdir="${REPO_ROOT}/infra/tf" output -raw host || true)"
  if [[ -z "${HOST}" ]]; then
    echo "failed to read terraform output 'host' (got empty value)" >&2
    exit 1
  fi
fi

# Простейшая валидация FQDN
if ! [[ "$HOST" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]]; then
  echo "HOST doesn't look like an FQDN: '$HOST'" >&2
  exit 64  # EX_USAGE
fi

export GATEWAY_HOST="${HOST}"

HTTPROUTE="${REPO_ROOT}/infra/apps/gateway/httproute.yaml"
CERTFILE="${REPO_ROOT}/infra/apps/gateway/cert.yaml"

# Бэкап
cp -f "$HTTPROUTE" "${HTTPROUTE}.bak"
cp -f "$CERTFILE"  "${CERTFILE}.bak"

# Правки через perl (в одну строку после нужного ключа)
perl -0pi -e '
  my $host = $ENV{GATEWAY_HOST};
  # заменяем ТОЛЬКО первую строку списка после hostnames:
  s/(hostnames:\s*\n)(\s*-\s*).*$/$1$2$host/m;
' "$HTTPROUTE"

perl -0pi -e '
  my $host = $ENV{GATEWAY_HOST};
  s/(domains:\s*\n)(\s*-\s*).*$/$1$2$host/m;
' "$CERTFILE"

# Проверим, что хост действительно попал в оба файла
if ! grep -q -- "$HOST" "$HTTPROUTE"; then
  echo "failed to update $HTTPROUTE; restoring backup" >&2
  mv -f "${HTTPROUTE}.bak" "$HTTPROUTE"
  exit 1
fi
if ! grep -q -- "$HOST" "$CERTFILE"; then
  echo "failed to update $CERTFILE; restoring backup" >&2
  mv -f "${CERTFILE}.bak" "$CERTFILE"
  exit 1
fi

echo "Gateway manifests now reference host: ${HOST}"
