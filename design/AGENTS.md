# design/ — Agent 原则

## 职责

产品**视觉与交互设计产物**：线框、高保真、导出图。  
面向 **AI 多风格、多轮探索 → 人选 → 再实现/上架**。

## 目录（双轨，wireframes 与 hi-fi 对称）

```text
design/
├── AGENTS.md
├── wireframes/
│   ├── _explore/           # 探索轨：可脏、多 batch
│   │   └── YYYY-MM-DD-<style-slug>/
│   │       ├── STATUS.md
│   │       └── <flow>/{nn}-{screen}[--state].ext
│   └── current/            # 当前轨：薄、默认真相
│       └── <flow>/…
└── hi-fi/
    ├── _explore/…
    └── current/…
```

| 路径 | 用途 |
|---|---|
| `*/_explore/` | 未选定的多版本/多风格稿（Design Explore Track） |
| `*/current/` | 当前采用稿（Design Current Track）；实现 UI 默认只读这里 |
| `*/_explore/<batch>/STATUS.md` | selected \| rejected \| superseded + 日期与 flow 说明 |

## 批次命名

`YYYY-MM-DD-<style-slug>`  
同日多轮：加 `-b` 或 `-HHMM`。  
禁止：`final`、`new`、`最终版` 作为 batch 名。

## 文件组织（current 与每个 batch 内相同）

- 按 **flow** 分子目录：`onboarding/`、`home/`…
- 文件：`{nn}-{screen-slug}[--state].ext`  
  例：`01-welcome.png`、`01-welcome--empty.png`
- 可选：`current/_index.md` 列屏幕清单

## 晋升（Design Promotion）

1. **复制**（不删 explore）某 batch 下的 **一个或多个 flow** → 对应 `current/<flow>/`  
2. 默认粒度：**按 flow**；不要默认整棵替换整个 `current/`  
3. 更新该 batch 的 `STATUS.md`（哪些 flow 被 selected）  
4. 非琐碎决策可再记一笔到 `docs/sessions/`

## 与 gtm

- 商店/宣发图 **只允许**从 `**/current/` 导出到 `gtm/`  
- **禁止**从 `_explore/` 直接进 gtm  
- 渠道尺寸裁切在 `gtm/`；视觉源在 `current/`

## Agent 默认行为

| 任务 | 路径 |
|---|---|
| 实现/对齐 UI | 只读 `wireframes/current` 与 `hi-fi/current` |
| 新风格/多版探索 | 只写 `_explore/<新 batch>/` |
| 用户说「用这版」 | 按 flow 晋升 + STATUS |
| 做商店截图 | current → gtm，并查 `gtm/specs/` |

未指明 batch 时，**不要**把 `_explore` 当产品 UI 真相。

## 版本与 git

- explore 与 current **默认都提交**  
- 图片建议 Git LFS（见仓库根 `.gitattributes` 若存在）  
- 大二进制撑爆时再考虑 archive；v1 不默认 gitignore `_explore/`

## 其它原则

1. 设计探索在本域；**上架终稿**在 `gtm/`。  
2. 不在此写业务需求正文（→ `PRODUCT.md` / `docs/prd`）。  
3. 本文件不规定具体品牌色或 UI 风格（那是 L3 / 选定后的设计决策）。  

实践摘要：[docs/guides/design-versions.md](../docs/guides/design-versions.md)
