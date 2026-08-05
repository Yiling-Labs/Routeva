# MVP 本地化策略：L2 · 壳层机翻 · 跟系统

> **闭集数量：** 原 S1（en · zh-Hans · es）已被 **ADR 0048（方案 M · 8 语）** 取代。本 ADR 仍约束 **策略**：L2、T1、U1。

MVP 多语言目标为 **L2**：String Catalog / 伪本地化锁布局；上架闭集见 **0048**，非无限语言。

**机翻范围（T1）：** 仅壳层（导航、Settings 行、按钮、空态、列表壳等）。**锁 English：** 诊断主文案与四桶、Repair 确认/进度/回滚、隐私关键句、付费墙。高风险键无合格译文时回落 en，不硬塞烂译。

**选择（U1）：** 仅跟 iOS 首选语言；**无** Settings Language 行。About 可一句次要机翻说明；无每屏 MT 条、无首次强选语言。RTL 等见 0048 后置。

**为何：** 机翻无人审下，诊断与同意文案是信任核心，不能与「语言越多越好」绑死；布局靠闭集抽检 + 伪本地化。

**后果：** 策略见 CONTEXT **Localization Policy**；闭集与 GTM 分层见 **0048** / **MVP Locale Set** / **GTM Language Set**。
