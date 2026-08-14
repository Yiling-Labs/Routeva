#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
IOS_ROOT="${SCRIPT_DIR:h}"
REPOSITORY_ROOT="${IOS_ROOT:h:h}"

typeset -a forbidden_paths
for relative_path in task_plan.md findings.md progress.md; do
  if [[ -e "$IOS_ROOT/$relative_path" ]]; then
    forbidden_paths+=("$relative_path")
  fi
done

if (( ${#forbidden_paths[@]} > 0 )); then
  print -u2 "Internal planning files must not be published:"
  print -l -u2 -- "${forbidden_paths[@]}"
  exit 1
fi

if git -C "$REPOSITORY_ROOT" ls-files app/ios | rg -q -- '(^|/)(\.build|\.swiftpm|build|DerivedData|Routeva\.xcodeproj|Vendor)/|\.(xcarchive|ipa|mobileprovision|p12|cer|pem|key)$'; then
  print -u2 "Generated, signed, cached, or binary iOS material is tracked."
  exit 1
fi

typeset -a active_paths=(
  "$IOS_ROOT/Sources"
  "$IOS_ROOT/Tests"
  "$IOS_ROOT/Scripts"
  "$IOS_ROOT/Config"
  "$IOS_ROOT/CoreSources"
  "$IOS_ROOT/Package.swift"
  "$IOS_ROOT/project.yml"
  "$IOS_ROOT/project.cores.yml"
  "$IOS_ROOT/CoreVersions.json"
  "$IOS_ROOT/README.md"
  "$IOS_ROOT/BUILDING.md"
  "$IOS_ROOT/THIRD_PARTY_NOTICES.md"
  "$IOS_ROOT/THIRD_PARTY_MODULES.txt"
)

if rg -n -i --glob '!audit-public-source.sh' 'xray' "${active_paths[@]}"; then
  print -u2 "Removed core reference found in active iOS release source."
  exit 1
fi

if rg -n --hidden --pcre2 '(github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|sk_(live|test)_[0-9A-Za-z]{16,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' "${active_paths[@]}"; then
  print -u2 "Credential or private-key pattern found."
  exit 1
fi

credential_matches="$(rg -n --hidden --pcre2 '(ss|vmess|vless|trojan|hysteria2|hy2|anytls|socks|socks5|tuic|https?)://[^[:space:]"<]+@|https://[^[:space:]"<]+(token|subscribe|subscription|api)[=/][^[:space:]"<]{8,}' "${active_paths[@]}" || true)"
non_fixture_matches="$(print -r -- "$credential_matches" | rg -v '\.invalid([/:?#]|$)|@(192\.0\.2|198\.51\.100|203\.0\.113)\.' || true)"
if [[ -n "$non_fixture_matches" ]]; then
  print -u2 "Non-fixture credential-bearing URL found:"
  print -u2 -r -- "$non_fixture_matches"
  exit 1
fi

python3 - "$IOS_ROOT" <<'PY'
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
catalog = json.loads((root / "CoreVersions.json").read_text())
if set(catalog["cores"]) != {"sing-box"}:
    raise SystemExit("CoreVersions.json must contain only sing-box")
core = catalog["cores"]["sing-box"]
for key in ("routevaPatch", "singTunPatch"):
    entry = core[key]
    path = root / entry["path"]
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != entry["sha256"]:
        raise SystemExit(f"Patch digest mismatch: {path}")
PY

print "Public iOS source audit passed."
