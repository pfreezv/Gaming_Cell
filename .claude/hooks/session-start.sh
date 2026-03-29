#!/bin/bash
set -euo pipefail

# Solo corre en entornos remotos (Claude Code en la web)
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Configurar identidad git si no está seteada
git config --global user.email "noreply@anthropic.com" 2>/dev/null || true
git config --global user.name "Claude" 2>/dev/null || true

# Verificar que el proxy git local está disponible
PROXY_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [ -n "$PROXY_URL" ]; then
  echo "[session-start] Remote origin: $PROXY_URL"
else
  echo "[session-start] WARN: No remote origin configurado"
fi

echo "[session-start] Proyecto PRIMORDIAL listo (Godot 4 — sin dependencias de paquetes)"
