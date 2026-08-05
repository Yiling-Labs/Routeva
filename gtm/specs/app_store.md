# Apple App Store — 素材与文案速查

> last_reviewed: 2026-08-05  
> **以 App Store Connect / Apple Human Interface 与截图规范为准**。设备分辨率随新品迭代。

## 图标

| 资产 | 尺寸 | 说明 |
|---|---|---|
| App Store icon | **1024×1024** | PNG，无 alpha（按苹果当前要求） |

## 截图（常用 iPhone 逻辑尺寸，上传前用官方校验）

| 设备档位 | 常见像素示例 | 说明 |
|---|---|---|
| 6.7" 档 | **1290×2796** | 大屏主截图组 |
| 6.5" 档 | **1284×2778** | 视 Connect 当前必填档位 |
| 6.1" 档 | **1179×2556** | 按需 |

- 竖屏为主；数量与必填机型以 Connect 为准
- 可加边框模板，但避免误导性虚假系统 UI

## 文案（常见上限）

| 字段 | 限制（量级） |
|---|---|
| Name | 30 字符 |
| Subtitle | 30 字符 |
| Keywords | 100 字符（逗号分隔，勿重复品牌堆砌） |
| Description | 4000 字符 |
| What's New | 4000 字符 |
| Promotional Text | 170 字符（可不发版更新） |

## 预览视频

- 可选；时长与规格见苹果「App Preview」文档
- 源片可放 `gtm/video/`，上架导出放本目录

## 目录约定

`gtm/stores/app_store/`
