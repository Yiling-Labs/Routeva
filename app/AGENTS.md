# app/ — Agent 原则

## 职责

**Application Source** 专用目录。init 只建占位与规则，**不**生成业务代码或框架工程。

## 通用（L0）

1. 应用代码与工程文件放本目录；不要在仓库根另起平行 `src/`（除非 ADR）。  
2. 设计稿、商店图、PRD 不进 `app/`。  
3. 密钥、证书、`.env` 禁止入库。  
4. **不在此文件写本产品功能列表**（功能写 `PRODUCT.md` / `docs/prd`）。  
5. 品类详单见 `docs/guides/`。  

## 已启用类型短规则（L2）

### ios

- Xcode/工程与源码在 `app/`：`project.yml` → `xcodegen generate` → `Routeva.xcodeproj`。见 `app/README.md`。  
- App Store 截图与元数据在 `gtm/stores/app_store/`。  
- 证书与配置描述文件不入库。


## 指南链接

- [common.md](../docs/guides/common.md) — 通用
- [ios.md](../docs/guides/ios.md) — iOS

