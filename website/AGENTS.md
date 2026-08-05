# website/ — Agent 原则

## 职责

产品**营销站 / 官网 / 法律页**工作区。

## 原则

1. 站点资产落在本目录（当前为静态 `public/`）；不要散落到 `app/` 或 `gtm/`。
2. `app/` 是产品应用本体；`website/` 是对外站——二者不要混目录。
3. SEO/上架草稿可在 `gtm/`；**Privacy / Terms 正式页**以本目录为准。
4. 生产域名：**https://routeva.yilinglabs.com**（Privacy：**`/privacy/`** · Terms：**`/terms/`**）。
5. 部署：Cloudflare Pages 项目名 **`routeva`**，产出目录 **`public/`**。见 `README.md`。
