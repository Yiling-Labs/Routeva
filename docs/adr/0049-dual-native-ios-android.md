# ADR 0049 — Dual-Native iOS + Android

## 状态

Accepted · 2026-08-06  

**编号独占：** **0049 = 仅本 ADR（Dual-Native）**。User Override Domain only 已改号为 **ADR 0057**（勿再写 0049）。

## 上下文

Routeva 原 Primary Type 为仅 `ios`。产品需**同时开发 iOS 与 Android 版本**，且保持一份产品语义（能力、非目标、IA、Craft 真源），避免拆成两个产品或两套能力列表。

对齐团队 LYSkills **ADR-0005**（Dual-Native Layout）与术语：Platform Realization、Platform Gap。

## 决策

1. **Types：** `primary = ios`，`secondary = android`（types: ios, android）。  
2. **布局：** Application Source 采用 Dual-Native：`app/ios/` 与 `app/android/`；两端互不 compile / import；`app/` 根不放第三套业务实现。  
3. **产品真源：** 能力与非目标在 `PRODUCT.md` / `docs/prd/`；UI 在 `design/**/current/`；领域词在 `CONTEXT.md`。  
4. **实现差异：** 平台 API（VPN、IAP、权限文案、后台限制等）记为 **Platform Realization**，不拆能力条目。  
5. **交付节奏：** 允许暂时 **Platform Gap**（一端领先），须在 PRD/status 显式；禁止静默漂移。  
6. **默认技术形态：** 双端原生（Swift/Kotlin 等与平台 API）；不以跨端 UI 壳为默认（若日后改用跨端，另开 ADR 推翻本条布局假设）。  
7. **GTM：** `gtm/stores/app_store/` + `gtm/stores/play_store/` 及对应 specs 并存。  

## 后果

- 工作区 L2 轨道含 `docs/guides/ios.md` 与 `android.md`；`app/AGENTS.md` 含 Dual-Native 段。  
- 实现启动后两端工程分别落在子树；共享的是文档/设计/契约，不是 compile-time 业务包。  
- 设计仍一套 current；控件/系统 chrome 可按 Realization 微调，不复制整套 IA。  

## 非决策（留给实现期）

- Android minSdk 具体数字、内核库选型、是否引入极薄契约文档目录（如 `docs/contracts/`）。  
- 双端 Beta / 商店上架日是否同日。  
