# Routeva

[![iOS CI](https://github.com/Yiling-Labs/Routeva/actions/workflows/ios.yml/badge.svg)](https://github.com/Yiling-Labs/Routeva/actions/workflows/ios.yml)
[![License: GPL v3 or later](https://img.shields.io/badge/License-GPL_v3_or_later-blue.svg)](LICENSE)

Routeva is a privacy-focused native iOS client for importing compatible proxy
subscriptions and running them through a single, pinned sing-box Packet Tunnel
runtime. The current public source corresponds to the Routeva iOS 1.0 (1)
release candidate.

The native iOS source is in [app/ios](app/ios). Start with:

- [iOS overview](app/ios/README.md)
- [reproducible build instructions](app/ios/BUILDING.md)
- [runtime pins and patch digests](app/ios/CoreVersions.json)
- [third-party notices](app/ios/THIRD_PARTY_NOTICES.md)
- [release gates](app/ios/Docs/ReleaseGateChecklist.md)

The repository intentionally excludes downloaded toolchains, generated Xcode
projects, Libbox binaries, caches, archives, certificates, profiles, and user
subscription data. The checked-in scripts reconstruct the runtime from an
exact sing-box commit and two verified Routeva patches.

Routeva is licensed under GPL-3.0-or-later. See [LICENSE](LICENSE) and
[NOTICE](NOTICE). Building the source does not grant Apple Network Extension,
App Group, CloudKit, signing, or App Store distribution permissions.

Security reports should follow [SECURITY.md](SECURITY.md). Contributions are
described in [CONTRIBUTING.md](CONTRIBUTING.md).
