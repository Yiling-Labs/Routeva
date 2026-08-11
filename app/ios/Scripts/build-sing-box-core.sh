#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
IOS_ROOT="${SCRIPT_DIR:h}"
source "$SCRIPT_DIR/bootstrap-go.sh"

BUILD_ROOT="$IOS_ROOT/.build/core-build/sing-box"
SOURCE_ROOT="$BUILD_ROOT/sing-box"
VENDOR_OUTPUT="$IOS_ROOT/Vendor/Libbox.xcframework"
SING_BOX_COMMIT="1086ab2563320e0da0c23b3a491d8dfa0939dff4"
PATCH_FILE="$IOS_ROOT/CoreSources/SingBoxBridge/patches/0001-packet-flow-datagram-bridge.patch"
SING_TUN_VERSION="v0.8.9"
SING_TUN_PATCH_FILE="$IOS_ROOT/CoreSources/SingBoxBridge/patches/0002-sing-tun-packet-flow-readv.patch"

mkdir -p "$BUILD_ROOT" "$IOS_ROOT/Vendor"
if [[ ! -d "$SOURCE_ROOT/.git" ]]; then
  git clone https://github.com/SagerNet/sing-box.git "$SOURCE_ROOT"
fi
git -C "$SOURCE_ROOT" fetch --tags --force
git -C "$SOURCE_ROOT" checkout --detach "$SING_BOX_COMMIT"
if git -C "$SOURCE_ROOT" apply --reverse --check "$PATCH_FILE" >/dev/null 2>&1; then
  echo "Routeva PacketFlow bridge patch is already applied."
else
  git -C "$SOURCE_ROOT" apply --check "$PATCH_FILE"
  git -C "$SOURCE_ROOT" apply "$PATCH_FILE"
fi
shasum -a 256 "$PATCH_FILE"

export GOMODCACHE="$IOS_ROOT/.build/go/pkg/mod"
export GOCACHE="$IOS_ROOT/.build/go/cache"
export GOPATH="$IOS_ROOT/.build/go/path"
export GOPROXY="${GOPROXY:-https://goproxy.cn,direct}"
export PATH="$GOPATH/bin:$PATH"
mkdir -p "$GOMODCACHE" "$GOCACHE" "$GOPATH/bin"

(
  cd "$SOURCE_ROOT"
  RESOLVED_SING_TUN_VERSION=$("$ROUTEVA_GO_ROOT/bin/go" list -m -f '{{.Version}}' github.com/sagernet/sing-tun)
  if [[ "$RESOLVED_SING_TUN_VERSION" != "$SING_TUN_VERSION" ]]; then
    echo "Unexpected sing-tun version: $RESOLVED_SING_TUN_VERSION" >&2
    exit 1
  fi
  "$ROUTEVA_GO_ROOT/bin/go" mod download "github.com/sagernet/sing-tun@$SING_TUN_VERSION"
)
SING_TUN_ROOT="$GOMODCACHE/github.com/sagernet/sing-tun@$SING_TUN_VERSION"
SING_TUN_PATCH_TARGETS=(
  "$SING_TUN_ROOT/tun.go"
  "$SING_TUN_ROOT/tun_darwin_gvisor.go"
  "$SING_TUN_ROOT/internal/fdbased_darwin/endpoint.go"
  "$SING_TUN_ROOT/internal/fdbased_darwin/packet_dispatchers.go"
)
chmod u+w "${SING_TUN_PATCH_TARGETS[@]}"
if git -C "$SING_TUN_ROOT" apply --reverse --check "$SING_TUN_PATCH_FILE" >/dev/null 2>&1; then
  echo "Routeva sing-tun PacketFlow readv patch is already applied."
else
  git -C "$SING_TUN_ROOT" apply --check "$SING_TUN_PATCH_FILE"
  git -C "$SING_TUN_ROOT" apply "$SING_TUN_PATCH_FILE"
fi
shasum -a 256 "$SING_TUN_PATCH_FILE"

"$ROUTEVA_GO_ROOT/bin/go" install github.com/sagernet/gomobile/cmd/gomobile@v0.1.12
"$ROUTEVA_GO_ROOT/bin/go" install github.com/sagernet/gomobile/cmd/gobind@v0.1.12
"$GOPATH/bin/gomobile" init

(
  cd "$SOURCE_ROOT"
  "$ROUTEVA_GO_ROOT/bin/go" run ./cmd/internal/build_libbox -target apple -platform ios
)

if [[ -e "$VENDOR_OUTPUT" ]]; then
  rm -rf "$VENDOR_OUTPUT"
fi
cp -R "$SOURCE_ROOT/Libbox.xcframework" "$VENDOR_OUTPUT"

find "$VENDOR_OUTPUT" -type f -print0 | sort -z | xargs -0 shasum -a 256
