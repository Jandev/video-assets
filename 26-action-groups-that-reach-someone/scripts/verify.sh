#!/usr/bin/env bash
# Verifies everything in this demo without deploying anything to Azure.
#
#   1. Bicep compiles - main.bicep and every module - with zero warnings.
#   2. main.bicepparam compiles.
#   3. Every shell script parses (bash -n).
#   4. Every PowerShell script parses (pwsh AST parser).
#
# This is the check to run before recording. It touches no Azure resources and
# needs no login.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FAILURES=0

pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; }
fail() { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; FAILURES=$((FAILURES + 1)); }
skip() { printf "  SKIP  %s\n" "$1"; }

echo
echo "=== 1. Bicep compilation ======================================================="
# A bicep compile warning looks like:  path(line,col) : Warning code: message
# The Azure CLI's own "WARNING: a new Bicep release..." notice is uppercase and
# is filtered out by matching the ": Warning " shape only.
for f in "$ROOT/infra/main.bicep" "$ROOT"/infra/modules/*.bicep; do
  LOG=$(mktemp)
  if az bicep build --file "$f" --stdout >/dev/null 2>"$LOG"; then
    if grep -qE ": Warning " "$LOG"; then
      fail "$(basename "$f") compiled with warnings:"
      grep -E ": Warning " "$LOG" | sed 's/^/        /'
    else
      pass "$(basename "$f") compiles cleanly"
    fi
  else
    fail "$(basename "$f") failed to compile:"
    sed 's/^/        /' "$LOG"
  fi
  rm -f "$LOG"
done

if az bicep build-params --file "$ROOT/infra/main.bicepparam" --stdout >/dev/null 2>&1; then
  pass "main.bicepparam compiles"
else
  fail "main.bicepparam failed to compile"
fi

echo
echo "=== 2. Shell script syntax ====================================================="
for f in "$ROOT"/scripts/*.sh; do
  if bash -n "$f" 2>/dev/null; then pass "bash -n $(basename "$f")"; else fail "bash -n $(basename "$f")"; fi
done

echo
echo "=== 3. PowerShell script syntax ================================================"
if command -v pwsh >/dev/null 2>&1; then
  for f in "$ROOT"/scripts/*.ps1; do
    if pwsh -NoProfile -Command "
      \$errors = \$null
      [System.Management.Automation.Language.Parser]::ParseFile('$f', [ref]\$null, [ref]\$errors) | Out-Null
      if (\$errors.Count -gt 0) { \$errors | ForEach-Object { Write-Error \$_.Message }; exit 1 }
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
if [[ $FAILURES -eq 0 ]]; then
  printf "\033[32mAll checks passed.\033[0m\n\n"
  exit 0
fi
printf "\033[31m%d check(s) failed.\033[0m\n\n" "$FAILURES"
exit 1
