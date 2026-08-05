# Routeva Visual System · 提取自 Home

> **权威视觉源：** [`02-home.html`](./02-home.html)  
> **约束：** 后续所有屏幕（Onboarding / Diagnostic / Repair / Activity / Agent / Settings…）**必须**从此系统取色、材质、字阶、圆角与动效气质。  
> 不必像素复制 Home 的每一个控件，但必须**协调统一、不违和**。禁止另起一套「扁平工具风 / 厚重卡片风 / 纯 iOS 默认列表风」与 Home 断裂。

## 1. 气质一句话

**Soft glass 消费级控件 × 冷静诚实的连接状态机。**  
精致、少字、大留白中部、底部或边缘承载主操作；可信 > 花哨。

## 2. 场域与皮肤

| Token | 用途 | 参考值（可微调，勿换族） |
|---|---|---|
| **Field Black** | 默认壳（多数二级页、失败、手势中） | 深炭灰竖向渐变 `#2e343a → #0b0e11` |
| **Field Green** | **仅** Connection Success 全屏（含状态栏连续） | 薄荷绿竖向渐变 `#4d7a6c → #1f3f38`，**无顶条色块** |
| 地图 / 点阵 | 极弱装饰 | 线稿 map 透明度 ≤0.1；halftone 偏下半屏 |

**禁止：** 二级页突然纯白大面积系统背景；绿场用于「装饰成功」以外的页面主底。

## 3. 材质：Soft Glass

| 控件 | 规则 |
|---|---|
| **Glass orb / chip** | 圆或大圆角；半透明白叠层 + 内高光 + 轻外阴影；`backdrop-filter` 模糊 |
| **Pill（Location 等）** | 同上，`border-radius: 999`；字 14 / 600 |
| **Sheet / 卡片** | 深底半透明玻璃板，大圆角 ~20–28；上沿细高光；可作底 sheet |
| **主按钮** | 薄荷绿实心渐变（与胶囊 STOP 同族）或 ghost 边框 |
| **次按钮** | 幽灵玻璃 / 细描边 |

**禁止：** 直角灰块列表；硬边纯色 Material 卡片与 Home 混搭。

## 4. 字阶与颜色（English UI）

| 角色 | 约 size | weight | 色 |
|---|---|---|---|
| 超大展示（时长） | 40 | 300 | 白 ~96% |
| 主状态 / 页标题 | 28–30 | 700 | 白 ~96% |
| 节点名 | 15–16 | 600 | 白 ~88% |
| 正文 / 说明 | 14–15 | 500 | 白 ~52–78%（≥ ~5:1 on Field Black） |
| 弱元信息（协议等） | 10–11 | 500 | 白 ~38%（装饰级；勿作任务正文） |
| 底注 / hint | 13 | 500 | 白 ~58%（≥ ~4.5:1；如 *Swipe down to connect*） |

字体：SF Pro Display / Text（system-ui）。  
**协议等次要信息必须弱化**，禁止彩色大徽章抢戏。  
**禁止：** 任务相关正文/页脚使用 ≤ ~40% 白（对比不足）。

## 5. 形状与间距

- **圆：** 国旗 orb、顶栏按钮、点阵粒子必须 **正圆**（等比 scale，勿改单轴尺寸）  
- **胶囊：** 主连接控件；圆角满圆  
- **Sheet 圆角：** ~24  
- **留白：** 中部信息区疏朗；底部主操作区给足呼吸  
- **Cover Flow：** 水平为主、**浅弧**（约 `y ∝ d²×2`）；item 间距适中  

## 6. 动效气质

| 类型 | 原则 |
|---|---|
| 时长 | 主交互 0.35–0.55s；点亮序列 ~0.6–1.0s |
| 曲线 | `cubic-bezier(0.22, 1, 0.36, 1)` 一类 ease-out |
| 点阵 | 仅连接过程；3 圈内→外；Idle 无点 |
| 场域切换 | 黑↔绿 **整屏交叉淡入**，禁止顶条残留 |
| Toast | 成功反馈 **2–3s** 自动消失；尊重 `prefers-reduced-motion`（可瞬时隐去） |
| 加载模态 | 短阻塞；spinner 在减动偏好下停转或静态环 |

**禁止：** 弹跳过度、花哨粒子与状态语义无关。

## 7. 导航壳（全 app）

- **无底部 Tab**  
- 顶栏：左右 **glass orb**（与 Home 同款）  
- **有订阅：** `[ Help ] [ Subscriptions ] …… [ Settings ]`（ADR 0020 / **0036**）  
- **Empty：** `[ Help ] …… [ Settings ]`（无 Subscriptions）  
- **Help** = soft glass **pill**（助手图标 + *Help* 字样），非抽象 Agent 圆标  
- **Activity** 不进顶栏、**不进** Settings 根页（ADR **0051**）；触点优先 Help / 诊断·Repair  
- 二级：push 或 sheet；关闭用 Close / 系统 back  
- 诊断 / 修复：优先 **底 sheet 玻璃卡**（与早期 probe 诊断语言一致）  

## 8. 各屏如何「提取」而非复制

| 屏幕 | 与 Home 的协调方式 |
|---|---|
| **Onboarding / Import** | Field Black；大标题 28–30；主 CTA 薄荷绿实心；少步骤。**Parsing** = 叠在 Add 上的玻璃 status 模态（非全屏）。成功 = Home Idle 同壳 + 短 toast（2–3s），不另起结果页 |
| **Location / 节点列表** | Field Black；顶栏同款；列表行 glass 分割或轻卡；协议弱标注 |
| **Diagnostic** | 叠在 dimmed Home（Can’t connect 黑场）；底 glass sheet；四桶白话；Why/Impact/Next；主 CTA；**次要 Ask Help**（Not sure 时可作主 CTA）。权威：`07-diagnostic.html` |
| **Repair** | 同场材质进度卡；Snapshot 文案；Cancel = ghost；验证后回绿场或失败 sheet |
| **Subscriptions** | Field Black；**单列表**（Active 行加强 + Update）；流量/到期有则显示、无则隐藏；**到期必带 Expires/Expired 标签**（已过期暖警示色，非连接绿）；禁止裸日期贴 nodes；**少文案**；无 All 第二层 |
| **Activity** | **非**独立一级/Settings 二级主入口（ADR **0051**）。若后续做完整时间线：Black 场；轻分割；图标线框、低饱和；优先从 Help / 诊断上下文进入 |
| **Help / Agent** | Black 场；顶 **信任条**（Cloud 默认 On）；空态求助文案 + chips；气泡轻量；输入条 glass 胶囊；边界页 Can/Can’t。权威：`06-agent.html`（ADR 0035–0043） |
| **Settings** | Black 场；分组标题弱字；glass Group 列表 + chevron；**Connection → App** 两段（**无** History · ADR **0051**）；App 仅 Subscriptions + About；隐私经 About → Privacy Policy；**无** 根页 Privacy / Appearance / Advanced / Cloud AI / Activity / Snapshots。**Overrides O3：** 空态/列表提示 *exceptions, not a full rule set*；CTA *Add exception*；根计数数字/None 不写 *rules*（ADR 0045）。权威：`05-settings.html` |

## 9. 自检清单（新屏交付前）

- [ ] 场域是 Black 或（仅成功态）Green，无突兀第三套主底色  
- [ ] 主控件 / 按钮 / 卡片能看出 soft glass 同族  
- [ ] 字阶与 Home 同档，协议/次要信息已弱化  
- [ ] 无底 Tab；顶栏语言一致  
- [ ] 圆是正圆；动效克制、语义清楚  
- [ ] 与 `02-home.html` 并排截图时 **不违和**  

## 10. 图标（Lucide · 单一来源）

- **Hi-fi 共享：** [`icons.js`](./icons.js)（Lucide Static v0.469.0 · ISC · `currentColor` · stroke **1.6** chrome / **2** CTA）
- **禁止**各页手绘 path 或混用 Heroicons / 多套库
- **SwiftUI：** 用 `icons.js` 头注释中的 **SF Symbols** 名称映射；勿把 SF 资源嵌进 HTML
- 主 Help 一律 `circle-help` / `questionmark.circle`（非 chat bubble）

## 11. 实现对照

改 UI 时优先读：`02-home.html` 内 `SKIN` / `TYPE` / `GlassOrb` / `ConnectStage` / `FlagOrb` 模式，再映射到 SwiftUI。

## 12. 共享 Token 基准（六屏已归一 · 2026-08-06 评审修复后）

新屏/改屏必须引用以下基准值，禁止另起变体：

| Token | 基准值 | 用途 |
|---|---|---|
| `T.quiet` | `rgba(255,255,255,0.38)` | **仅**装饰级弱元信息（协议、分组标题）；禁止任务正文 |
| `T.muted` | `rgba(255,255,255,0.58)` | 任务元信息 / hint / 底注（≥ ~4.5:1） |
| `T.secondary` | `rgba(255,255,255,0.55)` | 正文说明 |
| Hint 文本 | 13px / 500 / `T.muted` | 如 *Swipe down to connect* |
| Glass orb | `blur(16px) saturate(1.2)` · 0.5px 外环 · 白渐变 0.15→0.05→0.035 · 40×40 正圆 | 顶栏 chrome 唯一配方（以 `02-home.html` `glassSurface` 为准） |
| 卡片 | `linear-gradient(rgba(255,255,255,0.10), rgba(255,255,255,0.045))` · 圆角 20 | 列表卡 / Group 卡 |
| 警示 / 到期 | `rgba(255,176,120,0.95)` | Expired、表单错误等暖警示 |
| 动效曲线 | `cubic-bezier(0.22,1,0.36,1)` | 主交互 0.35–0.55s；toast 0.35s；toggle 0.2s |
| 按压反馈 | `:active scale(0.97)` + 契约曲线 | 全部按钮面统一 |
| Spinner | 0.9s linear | reduced-motion 下静态环 |
| 焦点环 | `:focus-visible` 2px mint（≈ `rgba(140,220,190,0.9)`） | 六屏统一，含 02-home |

**控件语义底线（实现对照稿同样遵守）：** 可点控件 = `<button>` 或带 tabindex/键盘处理；icon-only 控件必有 `aria-label`；switch 必有可访问名；sheet = `role="dialog"` + dismiss 路径（scrim / Escape / *Not now*）；toast = 稳定 `role="status"` 区域（非条件插入）。
