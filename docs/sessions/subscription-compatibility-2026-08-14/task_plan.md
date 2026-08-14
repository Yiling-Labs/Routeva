# Task Plan: 订阅 URL 修复与兼容性审计

## Goal
修复带端口/path/query 的 HTTPS 订阅 URL 被误判为 HTTP Proxy，并补齐可安全映射的标准订阅格式。

## Current Phase
Phase 5：交付

## Phases

### Phase 1: 复现与定位
- [x] 复现并脱敏分析真实订阅响应
- **Status:** complete

### Phase 2: 官方资料与兼容性审计
- [x] 查询 Mihomo、sing-box、Shadowsocks SIP008 官方资料
- **Status:** complete

### Phase 3: 实现
- [x] 修复 HTTPS 订阅与显式 Proxy 消歧
- [x] 新增 SIP008 JSON 支持与回归测试
- **Status:** complete

### Phase 4: 轻量验证
- [x] 完成语法、差异、敏感信息与 Xcode 编译证据检查
- **Status:** complete

### Phase 5: 交付
- [x] 汇总仍不支持的格式并交付
- **Status:** complete

## Decisions
- 带非根 path 或 query 的 HTTPS URL 一律走远程订阅请求。
- HTTPS authority-only 地址仅在有 userinfo 或 fragment 时视为显式 Proxy；裸 HTTP authority-only Proxy 保持支持。
- 支持 SIP008；不把完整 sing-box/Xray JSON 粗暴扁平化。
- 不覆盖并行任务的根目录规划文件或 SingBox 测试改动。

## Errors
- 初次抓取使用 zsh 只读变量 `status`；已改用 `http_code`。
- 临时目录删除被安全策略拒绝；已精确清空敏感文件。
- 两次记录/源码大补丁因上下文预期错误未应用；已拆分并按真实行号操作。
- Routeva scheme 专项测试被 `SingBoxConfigurationValidationTests.swift:340` 的并行语法错误阻断；改用单目标类型检查。
- 根目录规划文件被另一并行任务覆盖；本任务记录迁移至本目录。
- SharedKitTests 单目标构建被共享 DerivedData 中 Yams checkout 的 build 路径类型冲突阻断；不清理共享缓存，改用隔离 Swift 测试工具。
- 隔离 Swift 工具缺少 Yams 模块；三次不同测试环境尝试均被外部条件阻断后停止，保留 Xcode 已编译本轮源文件的证据。
