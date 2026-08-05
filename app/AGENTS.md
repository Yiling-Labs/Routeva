# app/ — Agent 原则

## 职责

**Application Source** 专用目录。init 只建占位与规则，**不**生成业务代码或框架工程。

## 当前状态

**设计定稿前：不在此目录写应用代码。**  
Craft / hi-fi 在 `design/` 收敛前，保持本目录仅占位；实现启动须用户明确确认。

## 通用（L0）

1. 应用代码与工程文件放本目录；不要在仓库根另起平行 `src/`（除非 ADR）。  
2. 设计稿、商店图、PRD 不进 `app/`。  
3. 密钥、证书、`.env` 禁止入库。  
4. **不在此文件写本产品功能列表**（功能写 `PRODUCT.md` / `docs/prd`）。  
5. 品类详单见 `docs/guides/`。  

## Dual-Native Layout（L0）

本产品 types 同时含 `ios` 与 `android`，采用 **Dual-Native**（ADR 0049；对齐 LYSkills ADR-0005）。

1. iOS 工程与源码仅在 `app/ios/`；Android 仅在 `app/android/`。  
2. 两端**不得**互相 compile / import；`app/` 根不放第三套业务实现（最多 README、伞形 CI、生成器）。  
3. 产品能力与非目标**单一来源**（`PRODUCT.md` / `docs/prd/` / `design/**/current/` / `CONTEXT.md`）。  
4. 平台 API/商店差异记为 **Platform Realization**；一端未交付记为 **Platform Gap**（须在 PRD/status 显式，禁止静默漂移）。  
5. 默认原生语言与平台 API（如 StoreKit vs Play Billing；Network Extension vs VpnService）；不以跨端 UI 壳为默认。  

## 已启用类型短规则（L2）

### ios

- **双端**（ios + android，Dual-Native）：iOS 仅在 `app/ios/`；不得 import / 编译 `app/android/`。  
- App Store 截图与元数据在 `gtm/stores/app_store/`。  
- 证书与配置描述文件不入库。  
- **设计定稿后再加入** Xcode 工程。

### android

- **双端**（ios + android，Dual-Native）：Android 仅在 `app/android/`；不得 import / 编译 `app/ios/`。  
- Play 素材在 `gtm/stores/play_store/`。  
- keystore / 签名密钥不入库。  
- **设计定稿后再加入** Android 工程。

## 指南链接

- [common.md](../docs/guides/common.md) — 通用
- [ios.md](../docs/guides/ios.md) — iOS
- [android.md](../docs/guides/android.md) — Android
