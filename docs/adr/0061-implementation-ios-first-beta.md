# 实现与 Beta 验证：iOS 先（设计仍 Dual-Native 单源）

**产品 / 设计 / copy / IA 仍双端同一能力表**（ADR **0049** 不推翻）。  
**编码启动后的实现节奏与 Beta 真机验证：iOS（iPhone）优先**；Android 同能力目标，允许 **Platform Gap** 标目标版本，不要求与 iOS 同日齐功。

## 相对 ADR 0049

0049 已允许「一端领先、须显式 Gap」。本 ADR **收紧默认节奏**：默认 **不**按「双端同 sprint 并行证明」排期，而以 **iOS 先证明 Self-Healing Loop + Table Stakes Connect**，再追齐 Android。

## 决策

1. **真源不变：** `PRODUCT` / PRD / CONTEXT / `design/**/current/` / `docs/copy` 继续 Dual-Native 单源；能力列表**不**按端永久分叉。  
2. **实现主轨：** 开工后优先 `app/ios/` 可安装 Beta（TestFlight）；关键路径 Craft 与自动化真连以 **iPhone** 为主验收。  
3. **Android：** 工程树 `app/android/` 可骨架并行，但 **不以 Android 阻塞 iOS Beta**；未交付项在 PRD / checklist / status **显式** Platform Gap + 目标里程碑。  
4. **已有 Gap：** iOS-only User Override iCloud（ADR **0054**）等继续；不因此把 Android 砍出产品。  
5. **GTM：** Brand Presence / 法律页可写双端意图；**商店上架日可不对齐**；未上 Play 前不假装可下载 Android。  
6. **隐私 / 合规文案：** 随实际交付端更新（例如仅 iOS Beta 时 Privacy 可写 iOS；Android 上线前补 Play 数据安全等）。

## 为何

自愈闭环与 VPN/探针尚未在任一端验证。双端同步实现把验证成本 ×2，且易在文档上「假齐」。iOS 先用更小矩阵证明产品赌注；设计单源避免日后 Android 另起产品。

## 后果

- PRODUCT / CONTEXT **Implementation Track**；checklist 勾选可 iOS 先行。  
- 禁止静默把 Android 能力从 MVP 列表删除而不改文档。  
- 若日后改为双端同日齐发，须新 ADR 或修订本条。

## 非决策

- Android minSdk 终稿、内核选型、是否引入共享契约目录。  
- 商业化是否双端同价同日。  
