# Progress

## 2026-08-14

- 建立 9 协议测试计划。
- 已完成一个公开 Clash.Meta 源的结构统计和当前解析器实测。
- 已运行 `swift test --filter SubscriptionParserTests`：27 项通过，0 失败。
- 下一步：为 9 种协议分别选择样本并执行解析/编译矩阵。
- 已建立权限为 0600 的临时样本目录，公开源内容不写入仓库。
- 已拆出 SS、VMess、VLESS、Trojan、Hysteria2、AnyTLS、TUIC、SOCKS5、HTTP 九份独立样本，每份最多 6 个节点。
- 已运行 `swift test --filter CoreConfigurationCompilerTests`：25 项通过，0 失败。
- 下一步：在已启动的 iPhone 17 Pro 模拟器上逐协议执行 Libbox 配置校验与 URL-test。
- 首次 Release 测试构建成功；因测试进程没有继承主机路径变量而被跳过，未计入协议结果。
- Base64 注入模拟器后，Shadowsocks、VMess、VLESS 完整真实测试通过；Trojan 完成内核运行但本轮节点全部超时。
- 后半批遇到共享工作区并行修改，改用已成功生成的测试产物执行 `test-without-building`。
- 缓存产物也不一致后停止复用；隔离临时验证包成功完成 9 协议、43 个真实样本的解析与配置编译，全部成功。
- 下一步：按当前已稳定源码重新执行完整 `SingBoxConfigTests`，验证内核接受协议配置。
- Routeva 自身加载器远程获取三份 HTTPS 订阅成功：142 个七协议节点、168 个 SOCKS5、724 个 HTTP。
- 当前源码专项结果：SubscriptionParser 27/27、CoreConfigurationCompiler 24/24、SingBoxConfigTests 7/7。
- 九协议均完成远程读取、真实样本解析、配置编译和对应内核证据；公网 URL-test 结果按可采信程度单独记录。
