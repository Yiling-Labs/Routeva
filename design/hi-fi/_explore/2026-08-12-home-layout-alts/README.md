# Home 布局探索 · Round 2

**状态：** explore（只做高保真，不进开发）  
**入口：** [`index.html`](./index.html)（必须 HTTP）

## Round 1 为什么全灭

| 问题 | 后果 |
|---|---|
| 把纵向 **START 胶囊**画成横条 | 产品 DNA 被毁，立刻「假 / 丑」 |
| 同一竖栈只挪间距 | 解决不了「谁是主视觉」 |
| 玻璃卡 / Dock / 底控制台 | AI 通用壳，不像 Routeva soft-glass 克制 |

## Round 2 原则

1. **ConnectStage 归位**（约 300pt 纵向仪表）— 布局必须围绕它，而不是假装它是底栏 pill  
2. **Cover Flow 与状态不能双英雄** — 一个主、一个副  
3. **禁止**为了分区而叠整块玻璃卡  
4. 功能闭集不变：全量循环 Cover Flow · B2 角标 · 节点名→Location · Mode · 下滑连接 · 绿场累计流量  

## 方案

| ID | 名 | 主张 |
|---|---|---|
| **0** | Current | 现网结构 · craft 修正对照 |
| **F** | Instrument | 胶囊=主仪表；节点=顶频道条；状态降为副文 |
| **G** | Single Orb | 单枚英雄旗球；状态/Mode 并一行 |
| **H** | Two Acts | 上选节点 / 下连接；发丝线分区 |
| **I** | Whisper | 状态作场域水印；锐利只留球与胶囊 |
| **J** | Rail | 节点压成顶轨；中下全给连接仪式 |

## 预览

```bash
python3 -m http.server 4320 --directory design/hi-fi/_explore/2026-08-12-home-layout-alts
# → http://127.0.0.1:4320/
```

回复：**F / G / H / I / J**，或混搭（例如「G 的球 + H 的分区」）。
