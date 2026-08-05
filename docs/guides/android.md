# Android 品类轨道（L2）

> Google Play 分发的 Android 应用。不规定具体功能或 UI 工具包。

## 商店与素材

- [ ] `gtm/stores/play_store/` 已用  
- [ ] 对照 [play_store specs](../../gtm/specs/play_store.md)：512 图标、feature graphic、截图  
- [ ] 短描述/完整描述草稿放 play_store 目录  

## 工程与合规（原则级）

- [ ] 工程与源码在 `app/android/`（Dual-Native；**设计定稿后再填入**；此前仅占位）  
- [ ] 签名密钥与 keystore **不入库**  
- [ ] 商店权限/数据安全表单与实现一致（上架阶段自检）  

## 文档

- [ ] 范围与平台说明见 `PRODUCT.md` 内容区  
- [ ] 与 iOS 共享能力列表；Play Billing / VpnService 等差异记 Platform Realization；一端未交付记 Platform Gap  

## 非目标（本 guide）

- 强制 Jetpack 组件选型或业务模块列表  
