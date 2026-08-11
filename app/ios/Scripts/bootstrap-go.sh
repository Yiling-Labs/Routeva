#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
IOS_ROOT="${SCRIPT_DIR:h}"
TOOLS_ROOT="$IOS_ROOT/.build/toolchains"
DOWNLOAD_ROOT="$IOS_ROOT/.build/downloads"
GO_VERSION="go1.26.2"
GO_ARCHIVE="$DOWNLOAD_ROOT/$GO_VERSION.darwin-arm64.tar.gz"
GO_URL="https://go.dev/dl/$GO_VERSION.darwin-arm64.tar.gz"
GO_SHA256="32af1522bf3e3ff3975864780a429cc0b41d190ec7bf90faa661d6d64566e7af"
GO_ROOT="$TOOLS_ROOT/$GO_VERSION/go"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  print -u2 "This bootstrap is pinned for Darwin arm64."
  exit 1
fi

mkdir -p "$TOOLS_ROOT/$GO_VERSION" "$DOWNLOAD_ROOT"

if [[ ! -f "$GO_ARCHIVE" ]]; then
  curl --fail --location --retry 3 "$GO_URL" --output "$GO_ARCHIVE"
fi

ACTUAL_SHA256="$(shasum -a 256 "$GO_ARCHIVE" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$GO_SHA256" ]]; then
  print -u2 "Go archive checksum mismatch."
  exit 1
fi

if [[ ! -x "$GO_ROOT/bin/go" ]]; then
  tar -xzf "$GO_ARCHIVE" -C "$TOOLS_ROOT/$GO_VERSION"
fi

export ROUTEVA_GO_ROOT="$GO_ROOT"
export PATH="$ROUTEVA_GO_ROOT/bin:$PATH"
