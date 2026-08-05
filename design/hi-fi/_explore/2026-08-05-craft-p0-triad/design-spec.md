# Routeva Craft P0 — 三方向共用 Design Spec

## 产品

**Routeva**：智能代理客户端。用户自备 Subscription；粘贴即连；诚实四桶诊断；可回滚的一键 Repair。不卖节点。美区叙事优先，UI **English**。

## 受众与场景

已有订阅、会复制链接、不懂协议的普通人。一手持 iPhone，在咖啡馆/家里想稳定打开常用服务。失败时要看懂「是我这边还是服务商」，可修时敢点一下。

## 情感基调

**可信、冷静、诚实** — 不是炫技 AI，不是黑客终端炫酷。诊断反馈质感 ≥ 装饰动效。

## 输出

- 形态：iOS App 高保真方向板（iPhone 15 Pro 逻辑框 393×852）
- 每方向展示 **4 主屏**并排：Home Connected · Diagnostic (Client-Fixable) · Repair Confirm · Import
- 可本地 `file://` 打开；选定后再做完整可点闭环

## 必含内容（三版同文案）

- 品牌字标：Routeva  
- Home：大连接态、Verified / Connected、节点名、Auto、一句健康说明  
- Diagnostic：Bucket **Client-Fixable**、原因、影响、下一步、置信度、Repair CTA  
- Repair：将尝试动作摘要 + Confirm / Cancel  
- Import：粘贴订阅入口 + 不卖节点提示  

## 约束

- 无付费墙（Beta）  
- 禁止紫渐变 AI slop、emoji 当图标堆砌  
- Connection Success ≠ 仅 VPN 图标  
- 无真实 logo 资产 → 用字标；选定后可替换  

## 视觉母题（内容长出的 form）

**「探针灯 + 诚实标签」**：连通性像一盏被验证过的灯；故障用四桶标签说人话，而不是错误码墙。

## 五问（form）

| 问 | 答 |
|---|---|
| 叙事角色 | Home=日常主舞台；Diagnostic/Repair=关键决策页 |
| 观众距离 | 10cm 手机 |
| 温度 | 冷静可信，Repair 时略升温（行动） |
| 容量 | 每屏 1 主动作；诊断卡信息密度高但可扫读 |
| 母题 | 验证过的连接灯 + Failure Bucket 标签 |

## 三方向差异轴

| | 逻辑 | 骨架差异 | 气质 |
|---|---|---|---|
| A | 轮盘 #17 Functional Brutalism | 列表/发丝线/系统字高密度 | 极客工具诚实 |
| B | 标杆：iOS 系统工具 + WARP 式冷静 | 居中大连接控件 + 分组列表 | 系统原生信任 |
| C | 设计师：出版级暖色编辑感 | 诊断卡杂志标题层级 | 温暖专业自愈 |
