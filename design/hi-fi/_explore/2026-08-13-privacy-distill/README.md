# Data & Privacy distill · 去掉解释，只留两个词 + 链接

**日期：** 2026-08-13  
**状态：** selected → **A · Stack**（已升 `03-setup.html` + `DataAndPrivacyView`）  
**范围：** 只改首次 Data & Privacy 文案密度。场域、Continue、First-run 位置（Welcome → 本页 → Home Empty）不动。

## 为什么动

现稿用标题 + 三张卡把合规说完：

> Credentials stay on this device / Only domain exceptions use iCloud / No analytics or cloud help

这是在替用户读完隐私政策。Guideline 5.4 需要一次披露，不需要一篇说明书。

两个真词就够：

| 词 | 对应事实 |
|---|---|
| **On device** | 订阅链接和凭证不上传 |
| **No tracking** | Beta 无分析、广告、崩溃 SDK、云助手 |

iCloud 域名例外、其余边界 → 外链 [Privacy Policy](https://routeva.yilinglabs.com/privacy/)。  
不上屏「No cloud」—— Override 备份是真的（ADR 0054）。

## 方案

| ID | 名 | 做什么 |
|---|---|---|
| **0** | Current | 对照：眉题 + 长标题 + 三张说明卡 |
| **A** | Stack | 两词当标题，左对齐，现 Welcome 同构 |
| **B** | Breath | 收成一句 *On device. No tracking.* |
| **C** | Caption | 词降到 CTA 上，中部留空 |

A / B / C 都在 Continue 上放 *Privacy Policy*。

```bash
python3 -m http.server 4311 --directory design/hi-fi/_explore
# http://127.0.0.1:4311/2026-08-13-privacy-distill/
```
