#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FAILURES=0
export DOTNET_BUNDLE_EXTRACT_BASE_DIR="${DOTNET_BUNDLE_EXTRACT_BASE_DIR:-$ROOT/.verify-work/dotnet-bundle}"
mkdir -p "$DOTNET_BUNDLE_EXTRACT_BASE_DIR"
pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; }
fail() { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; FAILURES=$((FAILURES + 1)); }

echo "=== Bicep ================================================================"
LOG="$(mktemp)"
if az bicep build --file "$ROOT/infra/main.bicep" --stdout >/dev/null 2>"$LOG"; then
  if grep -q " : Warning " "$LOG"; then
    fail "main.bicep compiled with warnings"
    sed 's/^/        /' "$LOG"
  else
    pass "main.bicep compiles without warnings"
  fi
else
  fail "main.bicep failed to compile"
  sed 's/^/        /' "$LOG"
fi
rm -f "$LOG"

if az bicep build-params --file "$ROOT/infra/main.bicepparam" --stdout >/dev/null 2>&1; then
  pass "main.bicepparam compiles"
else
  fail "main.bicepparam failed to compile"
fi

echo "=== Python ==============================================================="
if python3 -m compileall -q "$ROOT/src"; then
  pass "all Python files compile"
else
  fail "Python compilation failed"
fi

echo "=== Shell ================================================================"
for file in "$ROOT"/scripts/*.sh; do
  if bash -n "$file"; then pass "$(basename "$file") parses"; else fail "$(basename "$file") failed to parse"; fi
done

if command -v pwsh >/dev/null 2>&1; then
  for file in "$ROOT"/scripts/*.ps1; do
    if pwsh -NoProfile -Command "
      \$errors = \$null
      [System.Management.Automation.Language.Parser]::ParseFile('$file', [ref]\$null, [ref]\$errors) | Out-Null
      if (\$errors.Count -gt 0) { exit 1 }" >/dev/null 2>&1; then
      pass "$(basename "$file") parses"
    else
      fail "$(basename "$file") failed to parse"
    fi
  done
fi

if [[ $FAILURES -eq 0 ]]; then
  printf "\n\033[32mAll checks passed.\033[0m\n"
  exit 0
fi
printf "\n\033[31m%d check(s) failed.\033[0m\n" "$FAILURES"
exit 1
