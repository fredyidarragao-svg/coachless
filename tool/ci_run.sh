#!/usr/bin/env bash
# Ejecuta un comando; si falla, publica las últimas líneas útiles como anotación de error
# para poder leerlas desde la API de GitHub.
set -o pipefail
LOG=$(mktemp)
"$@" 2>&1 | tee "$LOG"
code=${PIPESTATUS[0]}
if [ "$code" -ne 0 ]; then
  msg=$(grep -E "error|Error|ERROR|FAILURE|What went wrong|Exception|because|^\s+-|•" "$LOG" | grep -v "^\s*$" | tail -n 120 | sed 's/%/%25/g' | awk '{printf "%s%%0A", $0}')
  echo "::error title=Fallo en: $*::${msg:0:60000}"
fi
exit $code
