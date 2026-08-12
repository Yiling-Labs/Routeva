# Cover Flow latency badge — **shipped B2**

**Status:** approved · 2026-08-12  
**Product:** Routeva · ADR **0068**  
**Code:** `CoverFlowLatencyBadge` in `app/ios/Sources/RoutevaApp/HomeView.swift`

## Spec (B2 · Inset glass + ms + tier color)

- **Placement:** chip inset on the flag disc bottom arc (not hanging under the orb).
- **States:**
  | State | Label | Glass |
  |-------|-------|--------|
  | Untested | *(none)* | — |
  | Testing | `…` | neutral |
  | Measured | `NNms` | tier color |
  | Timeout | `—` | poor (soft coral) |

- **TCP RTT tiers:**
  | Tier | Condition | Tint |
  |------|----------|------|
  | good | &lt; 100 ms | mint green glass |
  | fair | 100–200 ms | soft amber |
  | poor | &gt; 200 ms or timeout | soft coral |

Location list still uses spaced copy like `97 ms` / `Timeout`; orb uses compact `97ms`.

## Exploration archive

`index.html` keeps A / B / B2 / C / D for history. **Ship = B2 only.**

```bash
python3 -m http.server 4311 --directory design/hi-fi/_explore
# http://localhost:4311/2026-08-12-coverflow-latency-badge/index.html
```
