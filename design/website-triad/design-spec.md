# Routeva Marketing Site · 三方向共同 Spec

> 花叔 Design Fallback · Phase 3  
> 输出：官网落地页 HTML 方向初稿（1440×900 可视区截图）  
> 选定前 **不** 覆盖 `website/public/` 生产文件

## 产品是什么

**Routeva**：已有代理订阅用户的智能代理客户端。不卖节点。  
核心闭环：**Paste → Connect → Explain → Repair**（Self-Healing Loop）。  
Thick Agent 用户可见为 **Help**；Cloud 默认开可关；故障裁判是 Diagnostic Engine。  
Dual-Native iOS + Android；Beta 全功能免费；官网 Brand Presence 阶段（ADR 0052）。

## 受众与场景

- 会复制订阅链接、不懂协议细节的普通用户  
- 次级：有经验但不想维护配置的人  
- 场景：浏览器打开 `routeva.yilinglabs.com`，30 秒内理解「是谁 / 不卖什么 / 长什么样」

## 核心信息（三版同文案）

1. **Your subscription, not ours.**  
2. 不卖、不荐节点。  
3. 连上要探针真值；失败要白话分桶；Repair 要同意 + 快照 + 可回滚。  
4. Help 有云辅助但可关。  
5. 尚未上架：诚实 *not on the stores yet*，无伪 Download。

## 必含板块

- 身份 Hero（一句话 + 状态）  
- 产品静帧（真图：`home-connected` / `diagnostic-app-fix` / `help-empty`）  
- 立场 2–4 条  
- How it works 四步  
- Trust + Privacy / Terms 链  
- Footer · Yiling Labs

## 视觉母题（从 App 长出来）

**Soft glass 消费级控件 × Field Black / Field Green × 薄荷绿实心主操作 × 冷静诚实。**  
权威：`design/hi-fi/current/craft-p0/visual-system.md` + `02-home.html`。  
禁止：紫渐变 SaaS slop、假指标、协议军备、假商店按钮、另起纯白轻拟物。

## 色板（三版共用，可改结构）

| Token | 约值 |
|---|---|
| Field Black | `#2e343a → #0b0e11` |
| Field Green | 仅成功态引用截图内已有 |
| Mint CTA | `#7fd9b0` 族 |
| Ink | 白 88–96% |
| Secondary | 白 52–78% |

## 字体

- Display：系统栈或 Source Serif / Sora 其一（三版可换配对）  
- Body：`-apple-system` / Source Sans 3  
- 英文源文案

## 输出格式

- 单文件 HTML，viewport 截图 **1440×900**  
- 路径：`design/website-triad/design-demos/`  
- 内容必需图：同目录三张 PNG（已齐）

## 约束

- Brand Presence：主 CTA = 页内 How it works / 看产品  
- Legal URL 保持 `/privacy/` `/terms/`  
- 不编造用户数、评分、协议数量  
- 三版**布局骨架互异**（导航 + 主区结构至少一项结构性不同）

## Assumptions（未再追问）

1. 彻底重构 = 先定视觉方向再落 `website/public`，本轮只交付三方向。  
2. 气质以 craft-p0 **current** 为准，explore 三向作对照不覆盖 app 真源。  
3. 仍用已有 hi-fi 静帧，不新绘假 UI。  
4. 生产 SEO / 多语言后置。
