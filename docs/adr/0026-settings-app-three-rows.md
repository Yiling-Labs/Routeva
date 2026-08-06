# Settings · App 段（Beta）

**Slug：** `0026-settings-app-three-rows`（2026-08-06 自 `…-four-rows` **改名**——App 段固定三行）

Settings 根页 **App** 段为三行（自上而下）：**Auto-update subscription**（Toggle，默认开）· **Subscriptions ›**（深链）· **About ›**（**0028** 去 Appearance；**0034** 去根页 Privacy）。Beta **不**放 Restore Purchases、付费墙、账号。

**为何：** Empty 时顶栏无 Subscriptions，Settings 深链保证管理入口对称；自动刷新总闸与列表管理同段、开关在上（策略先于 CRUD）；About 收纳版本与隐私入口。Restore 在无 IAP 的 Beta 易成死行，商业化再加。

**后果：** 见 CONTEXT **Settings Surface** App 条、**Subscription Refresh**、ADR **0015** / 0028 / 0034。Hi-fi `05-settings.html` 须展示三行 App 段。
