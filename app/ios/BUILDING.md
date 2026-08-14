# Building Routeva for iOS

This document describes the preferred source form for Routeva iOS 1.0 (1).
Generated projects, downloaded toolchains, Go module caches, Libbox binaries,
archives, signing identities, and provisioning profiles are not source and are
not committed.

## Requirements

- Apple silicon Mac running macOS
- Xcode 26.6 command-line tools
- Git, curl, Python 3, and the system `shasum`
- XcodeGen 2.45.4
- Network access to GitHub, go.dev, and the configured Go module proxy

Routeva downloads Go 1.26.2 itself and verifies the archive against the
SHA-256 value in both `Scripts/bootstrap-go.sh` and `CoreVersions.json`.
A separately installed Go toolchain is not required.

## Foundation tests

These tests do not require Libbox or Apple signing:

```sh
cd app/ios
swift test
```

## Generate the unsigned project

Generate the fallback project before the runtime framework is available:

```sh
cd app/ios
xcodegen generate --spec project.yml
xcodebuild \
  -project Routeva.xcodeproj \
  -scheme Routeva \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Rebuild the pinned sing-box runtime

```sh
cd app/ios
./Scripts/build-cores.sh
xcodegen generate --spec project.cores.yml
```

The core script performs these verifiable operations:

1. Downloads and SHA-verifies Go 1.26.2 for Darwin arm64.
2. Checks out sing-box commit
   `1086ab2563320e0da0c23b3a491d8dfa0939dff4`.
3. Verifies and applies the checked-in Routeva sing-box bridge and uTLS ECH
   retry patches.
4. Resolves sing-tun v0.8.9, then verifies and applies the checked-in sing-tun
   PacketFlow patch.
5. Builds `Vendor/Libbox.xcframework` with the pinned gomobile toolchain.

Verify the device slice against `CoreVersions.json`:

```sh
shasum -a 256 Vendor/Libbox.xcframework/ios-arm64/Libbox.framework/Libbox
```

Regenerate the exact Go module/version record with:

```sh
./Scripts/generate-go-module-manifest.sh
git diff --exit-code -- THIRD_PARTY_MODULES.txt
```

## Linked Libbox tests

```sh
xcodebuild test \
  -project Routeva.xcodeproj \
  -scheme Routeva \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  ENABLE_TESTABILITY=YES \
  ONLY_ACTIVE_ARCH=YES \
  -only-testing:SingBoxConfigTests
```

The seven linked tests cover Smart and Direct DNS, real sing-box service startup,
the gVisor PacketFlow bridge, Hysteria2, the first-batch AnyTLS/SOCKS5/HTTP(S)/TUIC
outbounds, and supported Shadowsocks plugins.

## Signing

`project.yml` records Routeva's organization team for the official target.
Forks may override signing settings on the `xcodebuild` command line or in
their own local Xcode configuration. Do not commit certificates, private keys,
profiles, App Store credentials, or account-specific environment files.

The checked-in entitlements require App Groups, shared Keychain access,
Network Extension Packet Tunnel capability, and CloudKit for the official
bundle identifiers. Building source does not grant those Apple capabilities.

## Release correspondence

Each distributed binary must point to an immutable Git tag containing:

- the complete Routeva source used for the binary;
- `CoreVersions.json`;
- both core patches;
- all build and audit scripts;
- Swift package resolution;
- the generated Go module manifest and third-party notices.

Run `./Scripts/audit-public-source.sh` before publishing a source tag. The
development-signed `.xcarchive` is never a GitHub release asset because it
contains signing and provisioning material.
