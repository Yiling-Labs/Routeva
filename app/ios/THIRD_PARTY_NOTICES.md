# Third-party software notices and dependency record

Routeva is distributed under `GPL-3.0-or-later`. This record covers the
direct Swift packages and the pinned sing-box source inputs used by Routeva
iOS 1.0 (1). It is engineering evidence, not independent legal advice or App
Store/TestFlight approval.

| Component | Pinned version | Declared license | Current use |
|---|---|---|---|
| Routeva | 1.0 (1) | GPL-3.0-or-later | App, extension, bridge, build scripts and patches |
| sing-box / Libbox | v1.13.12 (`1086ab2`) | GPL-3.0-or-later | Sole runtime core; repository patches and build scripts included |
| sing-tun | v0.8.9 | GPL-3.0-or-later | gVisor TUN stack; repository PacketFlow readv patch included |
| sagernet/sing | v0.8.10 | GPL-3.0-or-later | Direct sing-box module dependency |
| sagernet/sing-shadowsocks | v0.2.8 | GPL-3.0-or-later | Direct sing-box module dependency |
| GRDB.swift | 7.10.0 (`36e30a6`) | MIT | Local SQLite persistence |
| Yams | 6.2.2 (`a27b21e`) | MIT | YAML subscription parsing |

The complete versioned Go module graph resolved from the pinned sing-box
checkout is committed as `THIRD_PARTY_MODULES.txt`. Regenerate it with:

```sh
./Scripts/generate-go-module-manifest.sh
```

The full GPL text is in the repository root `LICENSE`. Exact MIT license texts
for GRDB.swift and Yams are under `ThirdPartyLicenses/`. Go module source and
license files are obtained at the exact versions in
`THIRD_PARTY_MODULES.txt` by the Go module tooling during the reproducible
core build.

The sing-box source commit, Routeva patch paths and SHA-256 values, Go toolchain
archive digest, and reference arm64 binary digest are recorded in
`CoreVersions.json`. `Scripts/build-sing-box-core.sh` verifies and applies
all Routeva patches before building. Anyone distributing a different binary
must regenerate the module manifest and notices for that exact source graph.

Apple distribution terms, all transitive notice obligations, and App Store
review remain separate release gates requiring final legal review.
