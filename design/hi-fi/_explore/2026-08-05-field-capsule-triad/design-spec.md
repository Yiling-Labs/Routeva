# Design Spec · 2026-08-05-field-capsule-triad（三方向共同输入）

> 三个方向 subagent 的唯一共同输入。各自独立工作、互不参考。

## 产品是什么

**Routeva** — iOS 智能代理客户端（smart proxy client），面向**已有代理订阅、不懂协议/DNS/路由的普通用户**。不卖节点、不做国旗商城。核心价值闭环是 **Self-Healing Loop**：粘贴导入 → 自动连接 → 失败时诚实解释（诊断四桶）→ 用户确认后安全修复（快照+验证+可回滚）。

- 平台：iPhone 主验收，iOS 17+，美国 App Store 首发
- UI 语言：**English**（源语言，用户可见文案全部英文）
- Beta 阶段全功能免费，**无付费墙**
- 设计目标（Craft）：降低「工具感/山寨感」，让普通用户觉得**可信、冷静、精致**

## 锚点（三方向共同遵守的框架）

Pinterest pin（`../_refs/2026-08-05-pinterest-button-idea.jpg`，Jason Sanders 的 VPN 按钮概念稿）。从中提取的三个母题是**硬约束**，三方向都必须包含：

1. **场域色即状态** — 整块屏幕背景随连接真值切换色彩氛围，状态不是小圆点而是整个场域
2. **竖直滑动胶囊** — Home 唯一主动作（slide to connect / stop），有物理感、防误触
3. **径向点阵波纹** — 从胶囊向外扩散的点阵弧；**它不是装饰，是 Connectivity Probe 的可视化**

## 与 pin 的关键差异（Routeva 的诚实状态机，必须体现）

pin 只有两态（连上/没连上），Routeva 的 Connection Success = **系统隧道就绪 + Probe 验证通过**，缺一不可。所以场域色至少三态：

| 状态 | 场域色方向 | 含义 |
|---|---|---|
| Idle | 深炭/墨蓝 | 未连接 |
| Connected · **Verified** | 薄荷绿/青绿 | 隧道就绪 **且** Probe 通过（不许只亮 VPN 图标就宣称连上） |
| **Degraded** | 琥珀/灰黄 | 隧道亮了但 Probe 失败 —— pin 没有的第三态，是差异化核心 |

波纹语义：连接建立时逐圈点亮；Probe 失败时波纹在半途**碎裂/停滞**，并引向诊断卡。

## 必含的 5 块屏幕（方向板上平铺展示，英文文案）

1. **Home · Idle** — 深炭场域；START 胶囊；「Swipe up to connect」；顶部 pill = Active 订阅名（如「My Subscription」）+ Auto 模式
2. **Home · Connecting / Probing** — 过渡态；波纹逐圈点亮中；诚实文案（如「Verifying connection…」）
3. **Home · Connected · Verified** — 薄荷绿场域；「Verified · Connected」；当前节点名 + Auto；STOP 胶囊；完整成功波纹
4. **Home · Degraded** — 琥珀场域；诚实文案（如「Tunnel up — verification failed」）；波纹半途碎裂；「See diagnosis」入口
5. **Diagnostic · Client-Fixable** — 同视觉体系的诊断卡：四桶标签之一（Client-Fixable / Provider-Side / Environment / Unknown）+ 原因/影响/下一步/置信度 + Repair CTA（同形胶囊滑钮，「Slide to repair」）

## 明确不做（三方向都禁止）

- 国旗横条 / Location 选择器当主路径（那是卖节点的 VPN 范式；Routeva 自动选节点）
- Go Premium / 付费墙 / 皇冠图标
- 大计时器、上下行速率当主信息（最多极弱次要）
- 世界地图纹理、地球卖点
- 假绿：隧道亮但 Probe 失败时**不得**用绿色场域或「Connected」文案
- 装饰性 emoji 图标、紫渐变 AI slop、SVG 画人脸/物品

## 方向板（deliverable）要求

单文件 HTML（inline React + Babel，pinned 版本，iOS 设备框必须用 skill 的 `ios_frame.jsx`，禁止手写 Dynamic Island/状态栏），双击可开：

- 平铺 5 块 iPhone 屏幕（可静态，不要求交互）
- 一条色板条（三态场域色 + accent，标 oklch/hex）
- 字型选择（建议：衬线 display + `-apple-system` body，或方向自己的论证）
- 一个 120% 精致度的「签名细节」（如胶囊滑钮的微结构、波纹碎裂瞬间的放大帧）
- 一句气质定位 + 一句「form 来自内容的哪里」
- 截图：1600×1000 viewport，输出 `01-direction-board.png`

## 内容基调

可信 > 炫技。Routeva 的用户刚被别的客户端的 cryptic error code 伤害过；这个界面要让人第一眼觉得「它不会骗我」。诊断文案要具体、人话（如「All 12 nodes timed out — this is on your provider, not your phone」），不许含糊的「Network Error」。
