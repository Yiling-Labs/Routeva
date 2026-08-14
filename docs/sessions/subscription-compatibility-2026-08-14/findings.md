# Findings

- 用户接口对 Routeva User-Agent 返回 Base64 URI 列表，脱敏统计为 51 行：44 AnyTLS、4 Hysteria2、3 Trojan；没有 HTTP Proxy。
- 根因是 `isExplicitProxyNodeURI` 把任意带显式端口的 HTTPS URL 当作 Proxy，导致订阅 API 从未被请求。
- 当前支持容器：URI、Base64 URI、Clash YAML、Surge Profile；本轮新增 SIP008 JSON。
- 当前可执行协议：SS、VMess、VLESS、Trojan、Hysteria2、AnyTLS、SOCKS5、HTTP(S)、TUIC。
- 尚不支持完整 sing-box/Xray JSON 配置导入；这类配置包含 DNS、路由、selector/urltest 和出站引用，不能无损扁平化。
- 尚不支持 Mihomo 中超出当前协议模型的 SSR、Snell、Mieru、Hysteria v1、WireGuard、Tailscale、SSH、MASQUE、TrustTunnel、OpenVPN 等。
- 当前一键导入 scheme 只识别 Clash、Clash Meta、Stash、Surge；其他客户端专属 deep link 仍需按其正式语法逐个支持。其内部若直接包含可复制的 HTTPS URL，用户仍可粘贴原始 URL。
- 明文 HTTP 远程订阅被有意拒绝；官方 SIP008 同样要求使用 HTTPS，这属于安全策略而非兼容 Bug。
- SIP008 官方规范：https://shadowsocks.org/doc/sip008.html
- Mihomo 官方类型与 provider：https://wiki.metacubex.one/en/config/ 与 https://wiki.metacubex.one/en/config/proxy-providers/
- sing-box 官方出站配置：https://sing-box.sagernet.org/configuration/outbound/
