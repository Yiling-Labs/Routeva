# Product ↔ iOS implementation conflict ledger

This file records implementation constraints without modifying the current
product documents or design sources. Distribution still requires the remaining
release, legal and App Store gates.

| ID | Product/design source | Planned iOS behavior | Reason | Status |
|---|---|---|---|---|
| IOS-001 | Home and Diagnostic expose Help | Hide Help and Ask Help | AI/Help deferred for the first Beta | Implemented |
| IOS-002 | Help has Cloud assist on by default | No Cloud SDK, API key, or diagnostic upload | VPN privacy and review boundary | Implemented in App and Privacy page |
| IOS-003 | Domain Override is exact domain → proxy/direct | Core-native domain rules apply in Smart, Global, and Direct; the prior current-IP system exclusion is retired | User selected complete design semantics over the Apple-IP-only subset | Supersedes the earlier best-effort route implementation; Apple TN3120 release Gate remains |
| IOS-004 | Smart follows provider rules and Preferred affects only an honest subset | Provider rules classify traffic as DIRECT, REJECT, or proxy; every proxy result is forced through Routeva's current session node even when it is outside the provider group | Explicit product-owner decision to make Home's selected node control all proxied Smart traffic | Common inline rules implemented and core-validated; provider group egress, fixed-node, url-test, fallback, load-balance, and chain selection are intentionally collapsed; external RULE-SET/geodata remains fail-closed |
| IOS-005 | Direct is a routing mode and Overrides remain active in all modes | Direct keeps Packet Tunnel active and uses the Core direct outbound by default | Required for Domain → proxy Overrides and immediate mode switching | Supersedes the earlier stop-VPN implementation; Apple TN3120 release Gate remains |
| IOS-006 | First run has Welcome → Home Empty | Insert a one-time Data & Privacy disclosure | App Review Guideline 5.4 | Implemented |
| IOS-007 | Technical design includes cumulative traffic | Show only current duration and live Mb/s | No approved current product design for day/month panels | Implemented |
| IOS-008 | P0 protocol list is a product commitment | A/B/C support status follows available real-device evidence | No controlled test servers; user subscription is the only success source | Classifier/UI implemented; all current compatible profiles remain B pending real-device evidence |
| IOS-009 | Release identifier names one Packet Tunnel extension | Release build embeds one sing-box Packet Tunnel provider | User selected sing-box as the sole release runtime | Resolved |
| IOS-010 | Technical architecture assumes a supported TUN integration | sing-box exchanges packets through public `NEPacketTunnelFlow` and a Routeva-owned datagram socketpair | Avoid private descriptor access while retaining the gVisor data plane | Resolved and physically accepted |
| IOS-011 | Tunnel Extension must use extension-safe APIs | Current sing-box Libbox archive references `UIApplication` background-task symbols and links UIKit | Transitive upstream component in the pinned Apple build | Local linking enabled; binary/API audit required before distribution |
| IOS-012 | Current website Terms and marketing page still describe Help/cloud assist | App and Privacy page state that this Beta has no Help/cloud assist | Only the Privacy page was authorized for legal-copy revision in this implementation pass | Release content alignment blocker; product/legal decision required |
| IOS-013 | Home uses the generic connection-failure treatment | Debug Simulator builds explain that VPN connection testing requires a signed physical-iPhone build and do not start the connection state machine | The Simulator cannot exercise the signed Packet Tunnel provider lifecycle | Implemented for Simulator only; physical-device path accepted |
