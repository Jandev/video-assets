#!/usr/bin/env bash
# Verifies everything in this demo without deploying anything.
#
#   1. Bicep compiles cleanly (main + every module + the param file).
#   2. queries/*.kql have not drifted from the KQL embedded in log-alerts.bicep.
#   3. The .NET 10 API builds with warnings as errors.
#   4. Every .sh and .ps1 parses.
#   5. (optional) The KQL is validated against a live workspace when reachable.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FAILURES=0
WORKSPACE_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace-id) WORKSPACE_ID="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; }
fail() { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; FAILURES=$((FAILURES + 1)); }
skip() { printf "  SKIP  %s\n" "$1"; }

echo
echo "=== 1. Bicep compilation ======================================================="
LOG=$(mktemp)
if az bicep build --file "$ROOT/infra/main.bicep" --stdout >/dev/null 2>"$LOG"; then
  # The az CLI upgrade banner is "WARNING:" (upper) - a real Bicep warning is
  # "... : Warning BCPxxx". Match only the latter.
  if grep -q " : Warning " "$LOG"; then
    fail "main.bicep compiled with warnings:"
    grep " : Warning " "$LOG" | sed 's/^/        /'
  else
    pass "main.bicep and all modules compile without warnings"
  fi
else
  fail "main.bicep failed to compile:"
  sed 's/^/        /' "$LOG"
fi

if az bicep build-params --file "$ROOT/infra/main.bicepparam" --stdout >/dev/null 2>&1; then
  pass "main.bicepparam compiles"
else
  fail "main.bicepparam failed to compile"
fi
rm -f "$LOG"

echo
echo "=== 2. KQL drift check ========================================================="
if bash "$SCRIPT_DIR/validate-queries.sh" --sync-only >/dev/null 2>&1; then
  pass "queries/*.kql match the KQL embedded in log-alerts.bicep"
else
  fail "KQL drift between queries/*.kql and log-alerts.bicep - run validate-queries.sh"
fi

echo
echo "=== 3. .NET 10 API ============================================================="
if dotnet build "$ROOT/src/dotnet/Contoso.Demo.LogAlerts.slnx" -v q --nologo >/dev/null 2>&1; then
  pass "dotnet build (net10.0, warnings as errors)"
else
  fail "dotnet build failed:"
  dotnet build "$ROOT/src/dotnet/Contoso.Demo.LogAlerts.slnx" -v q --nologo 2>&1 | tail -20 | sed 's/^/        /'
fi

echo
echo "=== 4. Script syntax ==========================================================="
for f in "$ROOT"/scripts/*.sh; do
  if bash -n "$f" 2>/dev/null; then pass "bash -n $(basename "$f")"; else fail "bash -n $(basename "$f")"; fi
done

if command -v pwsh >/dev/null 2>&1; then
  for f in "$ROOT"/scripts/*.ps1; do
    if pwsh -NoProfile -Command "
      \$errors = \$null
      [System.Management.Automation.Language.Parser]::ParseFile('$f', [ref]\$null, [ref]\$errors) | Out-Null
      if (\$errors.Count -gt 0) { exit 1 }
      exit 0" >/dev/null 2>&1; then
      pass "pwsh parse $(basename "$f")"
    else
      fail "pwsh parse $(basename "$f")"
    fi
  done
else
  skip "pwsh not installed - PowerShell scripts not parsed"
fi

echo
echo "=== 5. Live KQL validation ====================================================="
if [[ -z "$WORKSPACE_ID" ]]; then
  WORKSPACE_ID=$(az monitor log-analytics workspace list --query "[0].customerId" -o tsv 2>/dev/null || true)
fi
if [[ -n "$WORKSPACE_ID" ]]; then
  if bash "$SCRIPT_DIR/validate-queries.sh" --workspace-id "$WORKSPACE_ID" >/dev/null 2>&1; then
    pass "all four queries are valid KQL against a live workspace"
  else
    fail "one or more queries are invalid - run validate-queries.sh to see which"
  fi
else
  skip "no reachable Log Analytics workspace - pass --workspace-id to validate KQL"
fi

echo
if [[ $FAILURES -eq 0 ]]; then
  printf "\033[32mAll checks passed.\033[0m\n\n"
  exit 0
fi
printf "\033[31m%d check(s) failed.\033[0m\n\n" "$FAILURES"
exit 1
