# Routeva iOS (`app/`)

Craft P0 **shell** — SwiftUI navigation and domain stubs aligned with CONTEXT / ADR 0018–0020 / 0033.

## Generate & open

```bash
cd app
xcodegen generate
open Routeva.xcodeproj
```

Requires: Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen), iOS 17+ simulator/device.

## What’s in this shell

| Area | Status |
|---|---|
| Welcome once → Home | Done (ADR 0019) |
| Top chrome Agent / Subscriptions / Settings | Done (Empty hides Subscriptions) |
| Add subscription + parsing overlay + toast | Stub import (always succeeds) |
| Subscriptions single list + Active / Update | Done (no All page) |
| Settings root sections | Skeleton + Subscriptions deep link |
| Connect gesture capsule | **Vertical swipe capsule** (START↓ / STOP↑ + 3 rings); VPN still stub |
| VPN / Network Extension / Probe | **Not yet** |
| Real subscription parse | **Not yet** |

## Next engineering slices

1. Network Extension + VPN permission on first connect  
2. Connectivity Probe → real Connection Success (ADR 0007)  
3. Clipboard / QR / file import pipeline + Display Name (ADR 0033)  
4. Persist subscriptions (Keychain / App Group as needed)  
5. Cover Flow node picker + polish capsule LED / reduced motion

Do not put store assets, secrets, or design HTML here — see repo `AGENTS.md`.
