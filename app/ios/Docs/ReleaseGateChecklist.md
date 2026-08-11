# Routeva iOS external TestFlight release gates

**Evidence date:** 2026-08-11
**Current decision:** **DO NOT DISTRIBUTE**

This checklist records release evidence without changing product or design
documents. A local pass is not a substitute for a signed physical-device pass.

| Gate | Current evidence | Status |
|---|---|---|
| Runtime source/build pin | sing-box v1.13.12 source commit, sing-tun v0.8.9, both Routeva patch SHA-256 values, Go toolchain and rebuilt arm64 binary hash match `CoreVersions.json` | Local pass |
| Open-source distribution license | Routeva has selected GPL-3.0-or-later and includes the full root license; complete transitive notice and independent App Store terms review remain | **Pending legal/release review** |
| Simulator app and provider | Release App, the sole sing-box Packet Tunnel extension, and PacketFlow bridge framework build on iOS 26.5 Simulator | Pass |
| Signed arm64 iOS product | Version 1.0 build 1 sing-box-only archive links, has required entitlements, passes deep signature/dependency validation, and the prior accepted build installs/launches on iOS 26.5.2 | Pass |
| Unit/model/parser/security tests | 126 Swift package tests pass, including public PacketFlow bridge tests | Pass |
| Linked core validation | All 5 Libbox tests pass, including complete Smart service startup, DNS preset validation, plugin validation, and framed gVisor UDP request/response through PacketFlow | Pass |
| Synthetic import UI flow | Locale-independent Home → Paste → refreshed Home → Location UI test passes | Pass |
| Provider policy | Clash/Mihomo and Surge rules normalize to typed ordered direct/current-node/reject policy; complete Smart policy starts in linked Libbox | Local pass |
| Automatic node failover | Smart without a persisted Preferred tries current then scored/provider-order candidates, bounded to three; Preferred, Global and Direct never switch automatically | Local pass; device failure matrix pending |
| Modern rule providers/geodata | HTTPS rule providers resolve during import/refresh without persisting credential URLs; GeoIP/GeoSite compile to pinned sing-box rule-set resources | Local pass; transitive asset/license review pending |
| Required localization bundles | en, zh-Hans, zh-Hant, es, pt-BR, ja, ko, de present | Pass |
| Runtime-data secret scan | Simulator app, arm64 device app and Simulator data container have no scanner matches | Local pass |
| Probe asset | `website/public/probe.txt` contains fixed `routeva-probe-v1` body | Deployed to Cloudflare Pages production; custom domain verified HTTP 200, exact body, `text/plain`, `no-store`, and `noindex` on 2026-08-07 |
| Privacy page | Beta behavior and private iCloud Override fields are aligned | Local file ready; deployment/legal review unverified |
| Signed Network Extension install | Host and the sing-box extension are signed with the organization team; the provider contains Packet Tunnel, App Group and shared Keychain entitlements | Pass |
| TUN descriptor bridge | sing-box gVisor uses a Routeva-owned datagram socketpair plus public `NEPacketTunnelFlow`; linked-core tests prove framed UDP ingress and response egress through the patched readv path | Pass |
| Real provider connection | User completed the signed physical-device connection acceptance; subscription material was never placed in source/log/chat | Pass |
| Protocol support A status | No profile has completed the required real-device matrix | **None; compatible profiles remain B/Experimental** |
| iPhone XS Max / iOS 18 | An iOS 18.7.9 iPhone is detected but offline; lock, switch-network, memory and reconnect matrix remain | **Pending connection/unlock** |
| iPhone 14 Pro Max / iOS 26 | User completed the signed sing-box physical-device acceptance and confirmed usable VPN startup | Pass |
| Domain Override | Core exact-domain rules apply in Smart/Global/Direct; reconnect consent and DNS/domain behavior still require device validation | **Pending physical device** |
| CloudKit private database | Container capability, development schema, merge, tombstone and restore | **Pending signed device/account** |
| Resource limits | ≤25 MiB idle, ≤35 MiB normal, ≤42 MiB peak | **Pending Instruments/device** |
| 24-hour soak | No sustained memory growth; lock/switch/recover cycles | **Pending** |
| Website content alignment | Terms/marketing still mention cloud Help outside authorized Privacy edit | **Product/legal blocker** |

## Protocol promotion rule

- **A / Supported:** the exact protocol + transport + security + UDP profile
  passes the signed-device connection matrix, including Probe success.
- **B / Experimental:** parsing/core configuration is compatible, but the exact
  profile lacks real-device connection evidence.
- **C / Unsupported:** no approved embedded core supports the exact profile;
  Routeva returns a stable reason and must not attempt a connection.

No release operator may promote B to A based only on parsing, compilation,
Simulator behavior, or a different protocol profile.
