# Routeva App Icon · 10 Concepts Spec

**Date:** 2026-08-06  
**Status:** Explore — 等用户从 10 方案中挑选 / 混合  
**Output:** `01-icon-board.html` · App Store 1024 语义 · 弹簧板小尺寸可读

## Product DNA（图标从哪长出来）

| 事实 | 图标含义 |
|---|---|
| 智能代理客户端，不卖节点 | 不做「盾牌 / 锁 / 地球密钥」VPN 滥俗符号 |
| Self-Healing + Connectivity Probe | 允许「环 / 探针 / 回路」母题 |
| Home 三圈点阵 + 滑动胶囊 | 产品独有 UI 签名，可抽象为 mark |
| Field Black + mint · Soft glass · Instrument Quiet | 色与材质对齐 craft-p0 / 官网 A |
| Routeva 名 | Route / via 路径感；可字母 R / 弧线 |

## Assumptions（可审计）

1. **交付目标：** 探索级 10 方向挑选板，非最终 1024 PNG 出稿。
2. **形状：** 画布为正方形；圆角由系统遮罩处理，设计时用 ~22.5% continuous-corner 预览。
3. **无字：** 主图标不出现 “Routeva” 全名（小尺寸糊掉）；字母仅限单字 monogram。
4. **无 alpha 语义：** 每版有实心底（Field Black / Field Green 或实心 mint 块），符合 App Store 无透明偏好。
5. **双端：** 同一 mark；Android adaptive icon 裁切区在选定后另做安全边。
6. **三方向精神：** 10 方案落在 3 个家族（UI 签名 / 路径语义 / 字标材质），一次摆齐供选。

## Form 五问

| 问 | 答 |
|---|---|
| 叙事角色 | 品牌入口 + 信任信号（Craft、仪器感，非促销噪点） |
| 观众距离 | 弹簧板 ~60pt 一眼可辨；1024 大尺寸仍耐看 |
| 视觉温度 | 冷静、诚实、精致；兴奋度低 |
| 容量 | 单符号 / 双元素上限；禁止多图层叙事 |
| 视觉母题 | **连接过程的三圈 / 胶囊 / 路径** — 品类里别人没有的 |

## 禁区

- 盾牌、锁、钥匙、假地球 wireframe、速度线条、火箭、紫色霓虹 glow
- 渐变彩虹「AI 感」、emoji、厚重 3D 塑料
- 与 craft-p0 断裂的纯白 Material / 高饱和橙红主底

## 色板（与 visual-system 对齐）

| Token | 值 |
|---|---|
| Field Black top | `#2e343a` |
| Field Black deep | `#0b0e11` |
| Field Green top | `#4d7a6c` |
| Field Green deep | `#1f3f38` |
| Mint | `#7fd9b0` |
| Mint lift | `#9ee8c4` |
| Glass edge | `rgba(255,255,255,0.14)` |
| Ink | `rgba(255,255,255,0.96)` |

## 10 方案一览

| # | 代号 | 家族 | 一句话 |
|---|---|---|---|
| 01 | Rings Probe | UI 签名 | Home 三圈 partial arcs |
| 02 | Capsule Thumb | UI 签名 | 竖直 START 胶囊剪影 |
| 03 | Route Arc | 路径 | 单条优雅路由弧 |
| 04 | Node Link | 路径 | 两点 + 柔连接 |
| 05 | R Monogram | 字标 | 精致 R 于 glass 圆场 |
| 06 | Field Success | 场域 | 整屏绿场 + 白探针 |
| 07 | Black→Green | 场域 | 对角双场 + 路径穿越 |
| 08 | Soft Core | 材质 | 深底 + 玻璃球 mint 芯 |
| 09 | Heal Loop | 语义 | 自愈回路（开口环） |
| 10 | Via Chevron | 路径 | 前进 via 双线 |

## 选定后下一步

1. 写 `direction-approved.md`（用户原话）  
2. 导出 1024 PNG（无 alpha）+ Android adaptive layers  
3. 同步 website wordmark 旁 favicon / 触感  
