# Routeva 多协议公开订阅验证计划

## 目标

逐项验证 Routeva 当前声明支持的 9 种协议：公开订阅获取、远程内容解析、节点归一化、sing-box 配置编译；在安全且可判定的条件下补充连通性验证。

## 范围

- Shadowsocks、VMess、VLESS、Trojan、Hysteria2、AnyTLS、SOCKS5、HTTP(S)、TUIC。
- 不使用公开节点承载账号登录、支付或其他敏感流量。
- 将“订阅读取成功”“配置编译成功”“远端节点连通”分开判定。

## 阶段

| 阶段 | 状态 | 内容 |
|---|---|---|
| 1. 建立测试矩阵 | completed | 确认可用公开 HTTPS 源及每种协议的候选节点 |
| 2. 真实订阅解析 | completed | 使用当前 SubscriptionParser 逐协议解析并记录跳过原因 |
| 3. 配置编译验证 | completed | 使用当前 CoreConfigurationCompiler 逐协议生成配置 |
| 4. 运行验证 | completed | 执行相关专项测试；可安全判定时验证公网连通性 |
| 5. 汇总 | completed | 给出每种协议的结果、限制与后续建议 |

## 完成标准

- 9 种协议每种均有独立结果。
- 每项明确区分解析、编译、运行/连通性三层。
- 失败项有稳定错误或不可判定原因，不把公共节点失效误判为程序缺陷。

## 错误记录

| 错误 | 尝试 | 处理 |
|---|---|---|
| Swift 解释器把 `.o` 当源码读取，报 invalid UTF-8 | 1 | 改用 `swiftc` 编译独立解析工具 |
| 独立解析工具首次缺少 CYaml 模块 | 1 | 加入项目构建产物中的模块映射 |
| 独立解析工具链接到重复 tracker object，报 duplicate symbol | 1 | 排除重复的 `SingBoxSelectorSelectionTracker.swift.o` 后成功 |
| 首次检索测试目录写成不存在的 `CoreConfigKitTests` | 1 | 根据 `find` 结果改用 `SharedKitTests` |
| zsh 中误用只读变量 `status` 保存退出码 | 1 | 后续统一改用 `test_exit_code` |
| `xcodebuild` 测试进程未继承主机订阅路径变量，真实测试被跳过 | 1 | 改为通过已启动模拟器的 `launchctl` 注入 Base64 样本 |
| 逐协议执行期间共享工作区相关源码被并行更新，后半批出现缺少 `compileLatencyProbe` / tracker 的编译错误 | 1 | 不覆盖并行改动；固定使用前三种已成功构建的 Release 产物，以 `test-without-building` 续跑 |
| `test-without-building` 发现构建产物中的测试包与 SharedKit 已被后续失败构建覆盖为不一致版本 | 1 | 停止复用缓存，改用隔离的临时验证包解析并编译真实样本 |
| 临时 Swift 包首次使用清单名作为本地依赖 identity，SwiftPM 识别为目录名 `ios` | 1 | 将 product 的 package identity 改为 `ios` |
| 隔离验证器解析依赖时远端 GRDB fetch 超过两分钟无进展 | 1 | 终止远端解析，显式复用项目已检出的 GRDB/Yams 本地路径 |
| 本机没有可直接使用的 `go` / sing-box CLI | 1 | 不临时安装工具；使用项目已集成的 iOS Libbox 专项测试做内核校验 |
