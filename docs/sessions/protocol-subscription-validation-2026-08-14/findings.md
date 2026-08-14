# Findings

## 已知基线

- `snakem982/proxypool` 最新 Clash.Meta HTTPS 订阅可被当前解析器读取。
- 2026-08-14 实测该订阅成功归一化 142 个节点：VLESS 70、Trojan 35、Shadowsocks 18、Hysteria2 12、VMess 4、AnyTLS 2、TUIC 1；另跳过 Mieru 1。
- 上述公开源不含 SOCKS5 与 HTTP 代理节点。
- Routeva 的远程订阅加载器只接受 HTTPS；HTTP authority-only 地址只作为显式 HTTP 代理节点处理。
- `SubscriptionParserTests` 专项测试 27/27 通过。
- 2026-08-14 重新获取公开源：ProxyPool 仍含 SS 18、VMess 4、VLESS 70、Trojan 35、Hysteria2 12、AnyTLS 2、TUIC 1。
- TheSpeedX 当次列表含 SOCKS5 2265 行、HTTP 2964 行；每种仅抽取前 6 个作为不可信公开样本。
- `CoreConfigurationCompilerTests` 专项测试 25/25 通过。
- 首轮真实 Libbox 结果：Shadowsocks 5/6、VMess 2/4、VLESS 5/6 返回有效 URL-test 延迟。
- Trojan 的 6 个样本已解析并启动 Libbox，但 12 秒内 0/6 返回延迟；这是公开节点当时不可达，不能据此判为协议实现失败。
- Hysteria2 及其后的首次执行被共享工作区并行源码更新造成的构建不一致打断，不计作协议结果。
- 隔离验证器按协议处理 43 个真实公开样本：SS 6、VMess 4、VLESS 6、Trojan 6、Hysteria2 6、AnyTLS 2、TUIC 1、SOCKS5 6、HTTP 6；43/43 解析、43/43 配置编译，0 跳过。
- Routeva 自身的 `SubscriptionPayloadLoader` 直接通过 HTTPS 获取三个公开源成功：ProxyPool 解析 142 个支持节点并跳过 Mieru 1 个；Proxifly SOCKS5 解析 168 个；Proxifly HTTP 解析 724 个。
- 当前稳定源码重新执行 `SubscriptionParserTests`：27/27 通过。
- 当前稳定源码重新执行 `CoreConfigurationCompilerTests`：24/24 通过。
- 当前稳定源码重新构建并执行 `SingBoxConfigTests`：7/7 通过；覆盖 Libbox 服务启动以及 Shadowsocks、VLESS、Trojan、Hysteria2、AnyTLS、SOCKS5、HTTP、TUIC 配置校验。VMess 另有本轮真实 URL-test 成功结果。

## 最终矩阵

| 协议 | 远程读取样本数 | 隔离样本解析/编译 | 当前 Libbox/运行证据 | 公网 URL-test |
|---|---:|---:|---|---|
| Shadowsocks | 18 | 6/6 | 通过 | 5/6 |
| VMess | 4 | 4/4 | 真实 URL-test 已启动成功 | 2/4 |
| VLESS | 70 | 6/6 | 通过 | 5/6 |
| Trojan | 35 | 6/6 | 通过 | 0/6（公开节点超时） |
| Hysteria2 | 12 | 6/6 | 通过 | 未形成可采信结果 |
| AnyTLS | 2 | 2/2 | 通过 | 未形成可采信结果 |
| SOCKS5 | 168 | 6/6 | 通过 | 未形成可采信结果 |
| HTTP | 724 | 6/6 | 通过 | 未形成可采信结果 |
| TUIC | 1 | 1/1 | 通过 | 未形成可采信结果 |

## 风险

- 公开节点来源未知且随时变化，只适合低风险连通探测。
- 公开节点不可达不能单独证明 Routeva 不兼容。
- 免费源中的 `skip-cert-verify`、非标准字段或转换痕迹可能影响单个节点。
- 公网 URL-test 未成功或未执行不等于协议不支持；程序兼容结论以真实订阅读取、解析、配置编译和当前 Libbox 校验共同判定。
