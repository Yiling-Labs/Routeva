#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 || ! -e "$1" ]]; then
  print -u2 "usage: audit-secret-leaks.sh <app-group-or-build-artifact>"
  exit 64
fi

SCAN_ROOT="$1"
PATTERN='(ss|vmess|vless|trojan|hysteria2|hy2)://[^[:space:]"<]+@|https://[^[:space:]"<]+(token|subscribe|subscription|api)[=/][^[:space:]"<]{8,}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'

typeset -a flagged
while IFS= read -r -d '' candidate; do
  kind=$(file -b "$candidate")
  if [[ "$kind" == *"Mach-O"* || "$kind" == *"current ar archive"* ]]; then
    continue
  fi
  if rg -a -q --no-messages --pcre2 "$PATTERN" "$candidate"; then
    flagged+=("$candidate")
  fi
done < <(find "$SCAN_ROOT" -type f -print0)

if (( ${#flagged[@]} > 0 )); then
  print -u2 "Potential Routeva secret material found in:"
  print -l -u2 -- "${flagged[@]}"
  exit 1
fi

print "No credential-bearing subscription URI, tokenized HTTPS URL, or private-key marker found under $SCAN_ROOT"
