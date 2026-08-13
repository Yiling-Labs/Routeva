# Welcome distill · 去掉解释，只留 2–3 个词

**日期：** 2026-08-13  
**状态：** selected → **A · Stack**（已升 `03-setup.html` + `WelcomeView`）  
**范围：** 只改 Welcome 文案密度与排版。场域、CTA、First-run 路径（Welcome 一次 → Home Empty）不动。

## 为什么动

现稿已经是 ADR 0019 的「headline + 一句副文」，但副文仍在解释产品：

> No technical setup. Connects first—and explains itself when it doesn’t.

Welcome 不负责把优势讲完。三个 MVP 真词就够：

| 词 | 对应能力 |
|---|---|
| **Paste** | 你已有订阅，粘贴即用 |
| **Connect** | 测节点、建 VPN、Probe 通过 |
| **Smart** | 应用内 Mode 名；智能选节点（不用 Auto，Home 也不出现该词） |

不写 Honest / 诊断（post-MVP）。不写 no-sell（只在 Add 脚）。不上品牌字。

## 方案

| ID | 名 | 做什么 |
|---|---|---|
| **0** | Current | 对照：双行标题 + 解释性副文 |
| **A** | Stack | 三个词当标题，左对齐，现稿重力 |
| **B** | Breath | 收成一句 *Paste. Connect. Smart.* 居中 |
| **C** | Caption | 词降到 CTA 上一行，中部留空 |

```bash
python3 -m http.server 4311 --directory design/hi-fi/_explore/2026-08-13-welcome-distill
# http://127.0.0.1:4311/
```
