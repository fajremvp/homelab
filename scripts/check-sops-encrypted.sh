#!/usr/bin/env bash
set -euo pipefail
for f in "$@"; do
  if ! grep -qE '^\s*"?sops"?\s*:' "$f"; then
    echo "❌ ERRO: $f não contém metadados sops. Bloqueando commit de segredo em texto plano."
    exit 1
  fi
done
