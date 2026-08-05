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
| 正文 / 说明 | 14–15 | 500 | 白 ~55–78% |
| 弱元信息（协议等） | 10–11 | 500 | 白 ~38% |
| 底注 / hint | 12 | 400 | 白 ~36–40% |

字体：SF Pro Display / Text（system-ui）。  
**协议等次要信息必须弱化**，禁止彩色大徽章抢戏。

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

**禁止：** 弹跳过度、花哨粒子与状态语义无关。

## 7. 导航壳（全 app）

- **无底部 Tab**  
- 顶栏：左右 **glass orb**（与 Home 同款）  
- 二级：push 或 sheet；关闭用 Close / 系统 back  
- 诊断 / 修复：优先 **底 sheet 玻璃卡**（与早期 probe 诊断语言一致）  

## 8. 各屏如何「提取」而非复制

| 屏幕 | 与 Home 的协调方式 |
|---|---|
| **Onboarding / Import** | Field Black；大标题 30；主 CTA 薄荷绿实心；少步骤 |
| **Location / 节点列表** | Field Black；顶栏同款；列表行 glass 分割或轻卡；协议弱标注 |
| **Diagnostic** | 叠在 dimmed Home 或 Black 场；玻璃大卡；四桶 badge 可略用色但不抢主 CTA |
| **Repair** | 同 Diagnostic 材质；Confirm = 绿实心；Cancel = ghost |
| **Activity** | Black 场；时间线轻分割；图标线框、低饱和 |
| **Agent** | Black 场；输入条 glass 胶囊形；气泡勿厚重拟物 |
| **Settings** | Black 场；分组标题弱字；toggle / chevron 克制 |

## 9. 自检清单（新屏交付前）

- [ ] 场域是 Black 或（仅成功态）Green，无突兀第三套主底色  
- [ ] 主控件 / 按钮 / 卡片能看出 soft glass 同族  
- [ ] 字阶与 Home 同档，协议/次要信息已弱化  
- [ ] 无底 Tab；顶栏语言一致  
- [ ] 圆是正圆；动效克制、语义清楚  
- [ ] 与 `02-home.html` 并排截图时 **不违和**  

## 10. 实现对照

改 UI 时优先读：`02-home.html` 内 `SKIN` / `TYPE` / `GlassOrb` / `ConnectStage` / `FlagOrb` 模式，再映射到 SwiftUI。
