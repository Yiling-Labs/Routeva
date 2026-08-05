# MVP Locale 闭集升级为方案 M（8 语）

**取代** ADR 0047 中的三语闭集（S1：en · zh-Hans · es）。**保留** 0047 的 L2 / T1 壳层机翻 / U1 跟系统 / 诊断与同意锁 English。

**App UI 闭集（M · 8）：**  
**en**（源，人工）· **zh-Hans** · **zh-Hant** · **es** · **pt-BR** · **ja** · **ko** · **de**（后七机翻壳层，无人审）。未匹配 → **en**。

**为何加到 8：** 产品要求明显大于三语覆盖；在代理受众（简繁中）、美区/拉美（es · pt-BR）、高 iOS 东亚（ja · ko）与欧洲长词压测（de）之间取可维护上限。仍拒绝 15+ 与 RTL/ru 首波捆绑。

**GTM 不同步 8 套：** P0 仅 **en** 全套精做；P1 **zh-Hans** 商店/运营；P2 按 ROI 加 es/ja 等 listing。完整多语言截图不与 App 8 locale 同日齐发。

**后置：** ar 等 RTL、ru、vi/id、fr/it 等另里程碑。

**后果：** CONTEXT **MVP Locale Set** / **Localization Policy** / **GTM Language Set**；0047 闭集段落以本 ADR 为准。
