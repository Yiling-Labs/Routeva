# Settings · App 段（Beta）

Settings 根页 **App** 段现为三行：**Privacy ›**、**Subscriptions ›**（深链）、**About ›**（**0028** 去掉 Appearance）。Beta **不**放 Restore Purchases、付费墙、账号。Privacy 不做 Cloud AI 开关（见 ADR 0025）。

**为何：** Empty 时顶栏无 Subscriptions，Settings 深链保证管理入口对称；Privacy/About 为标准 App 层。Restore 在无 IAP 的 Beta 易成死行，商业化再加。

**后果：** 见 CONTEXT **Settings Surface** App 条与 ADR 0028；About/Privacy 内容细项另议。
