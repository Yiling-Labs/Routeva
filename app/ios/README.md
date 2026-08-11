# Routeva for iOS

Routeva is licensed under `GPL-3.0-or-later`; copyright belongs to Routeva
contributors. The complete license text is in the repository root `LICENSE`.
The canonical source repository is
[Yiling-Labs/Routeva](https://github.com/Yiling-Labs/Routeva).

Routeva's release runtime is sing-box. The App embeds one Packet Tunnel
extension and reconstructs its configuration from a versioned manifest and
shared Keychain material at startup.

The sing-box runtime is pinned to v1.13.12 at commit
`1086ab2563320e0da0c23b3a491d8dfa0939dff4`. Routeva applies the two checked-in
patches: `0001-packet-flow-datagram-bridge.patch` adds the
Libbox platform bridge contract, and `0002-sing-tun-packet-flow-readv.patch`
selects sing-tun v0.8.9's socketpair-compatible gVisor reader. Routeva uses
only the public `NEPacketTunnelFlow` packet APIs. The extension does not extract
Apple's private `socket.fileDescriptor` value.

The current release-candidate source is version `1.0 (1)`. Build the pinned
runtime and generate the framework-linked project with:

```sh
./Scripts/build-cores.sh
xcodegen generate --spec project.cores.yml
```

The exact source commits, patch digests, and reference arm64 binary digest are
recorded in `CoreVersions.json`. Generated projects, framework binaries,
archives, provisioning profiles, and local caches are deliberately excluded
from Git.

For prerequisites, clean-checkout commands, signing overrides, and dependency
evidence, read [BUILDING.md](BUILDING.md). A source checkout and a successful
build are not App Store distribution approval; the remaining gates are tracked
in [Docs/ReleaseGateChecklist.md](Docs/ReleaseGateChecklist.md).

See:

- `BUILDING.md`
- `Docs/ProductImplementationConflicts.md`
- `Docs/ReleaseGateChecklist.md`
- `CoreVersions.json`
- `THIRD_PARTY_NOTICES.md`
- `THIRD_PARTY_MODULES.txt`
