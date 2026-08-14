# App Store Connect 提交文案 · Routeva 1.0 · 8 语

> last_reviewed: 2026-08-14  
> 主语言：**English (U.S.)** · 另 7 份 listing 与 App locale 闭集对齐：zh-Hans · zh-Hant · es · pt-BR · ja · ko · de  
> 口径：Crafted Connect / ADR **0071** / 当前 iOS Beta（**无 Help、无 Repair UI、无 IAP、不卖节点**）  
> 功效与隐私句为人工撰写，不是机翻终稿。截图仍只做 **English** 一套（ADR 0071），不要为 8 语各出像素。  
> 字符计数含空格与标点。关键词逗号后不要空格。

桌面图标名保持 **Routeva**（`CFBundleDisplayName`）。下面是商店显示名。

---

## 审查（相对上一稿改了什么）

以美区转化 + ASO + Guideline 2.3 为准，不是再写一套品牌诗。

| 级别 | 字段 | 问题 | 处理 |
|---|---|---|---|
| 高 | 各语 **Name / Subtitle** | 搜索只索引这两栏 + 关键词；描述不参与检索 | 每语名称 = 品牌 + 当地品类词；协议名只进关键词 |
| 高 | zh-Hans 副标题原 9/30 | 白白丢掉最高权字段 | 改为「粘贴已有订阅，一滑连接选节点」（14） |
| 高 | 描述里的 Cover Flow / Location | 实现黑话，商店读者不懂 | 各语改成「按地区选更快的节点」 |
| 中 | 全大写 WHAT YOU DO | 像 Play 功能表，不像本品牌 | 改成短祈使句小标题 |
| 中 | ja/ko「サブスク / 구독」 | 易被当成 App 内购 | 日语用「購読リンク」；韩语正文写清「已经在付的提供商订阅」 |
| 中 | 可见文案堆协议 / VPN | 2.3.7 元数据堆砌 + 招来要「自带服务器」的用户 | VPN 只放关键词；协议只在描述能力段出现一次 |
| 低 | zh 宣传文本过短 | 折叠前信息够用，但可补「不用注册」 | 已补 |

保留不动：`Routeva Proxy Client` 英文名（品牌 + 品类，不堆 VPN）；英文副标题 30/30；不卖节点放在折叠前三行；审核备注仍只写英文。

**不要写进任何语言：** 机场、科学上网、翻牆/翻墙、Our servers、90+ cities、解锁 Netflix、Help/AI 修网、竞品名（Shadowrocket / Quantumult / Surge / Stash / Clash / 小火箭）。

---

## App Store Connect 语言槽

| 本文件 | Connect 本地化 |
|---|---|
| en | English (U.S.) ← 主语言 |
| zh-Hans | Chinese (Simplified) |
| zh-Hant | Chinese (Traditional) |
| es | Spanish (Spain)；同一份可再贴到 Spanish (Mexico) |
| pt-BR | Portuguese (Brazil) |
| ja | Japanese |
| ko | Korean |
| de | German |

---

## 名称 / 副标题 / 关键词速查

| 语 | Name | n/30 | Subtitle | s/30 | KW |
|---|---|---|---|---|---|
| en | Routeva Proxy Client | 20 | Paste a subscription. Connect. | 30 | 100 |
| zh-Hans | Routeva 代理客户端 | 13 | 粘贴已有订阅，一滑连接选节点 | 14 | 99 |
| zh-Hant | Routeva 代理用戶端 | 13 | 貼上既有訂閱，一滑連接選節點 | 14 | 99 |
| es | Routeva Cliente Proxy | 21 | Pega tu suscripción. Conecta. | 29 | 98 |
| pt-BR | Routeva Cliente Proxy | 21 | Cole sua assinatura. Conecte. | 29 | 99 |
| ja | Routeva プロキシクライアント | 18 | 購読を貼るだけ。ノードを選ぶ | 14 | 95 |
| ko | Routeva 프록시 클라이언트 | 17 | 이미 있는 구독 링크로 바로 연결 | 18 | 91 |
| de | Routeva | 8 | Proxy für dein eigenes Abo. | 27 | 97 |

备选（审核嫌英文名太品类，或 Connect 报「名称已被使用」）：该语 Name 只填 `Routeva`，品类词挪进副标题。  
**德语已按此处理：** `Routeva Proxy-Client` / `Routeva Network Proxy Client` 这类泛名会被判占用。不要投诉，改名即可。

---

## en · English (U.S.)

**Name** `Routeva Proxy Client`

**Subtitle** `Paste a subscription. Connect.`

**Keywords**

```
vpn,v2ray,vless,vmess,trojan,shadowsocks,hysteria2,yaml,tunnel,latency,reality,xray,import,scan,node
```

**Promotional Text**

```
Connect without the maze. Paste the plan you already have, swipe once, and go online only when the path actually checks out. We don't sell nodes.
```

**Description**

```
Connect without the maze.

A proxy client for the subscription you already have. Paste a link, swipe once, and go online only when the path actually checks out.

We don't sell nodes.

Paste. Swipe. Green.
Paste, scan, or import a plan you already pay for. Swipe on Home. Green means you are reachable through your node — not just that a tunnel is up.

When you want a say
• Browse locations and pick a faster node
• Test latency to see what holds
• Smart mode follows your provider's rules
• Global mode sends everything through the node
• Pin a domain to proxy or direct
• Auto-update keeps the active plan fresh (you can turn this off)

If the path drops
Routeva can switch nodes so you stay online. Failures are short and honest.

Bring your own plan
A subscription or node list from a provider you choose. Common YAML files and node links work (VLESS, VMess, Trojan, Shadowsocks, Hysteria2). Speed, uptime, and which sites open depend on that provider — not on Routeva.

Not a VPN service
No servers of ours. No account. No ads. No tracker. No streaming-unlock promises.

Data stays on the device by default. The first time you connect, iOS asks for VPN permission so traffic can use your node.

Requires iOS 17 or later.

Privacy: https://routeva.yilinglabs.com/privacy/
Terms: https://routeva.yilinglabs.com/terms/
```

**What’s New**

```
Welcome to Routeva.

Paste a subscription you already have, swipe once, and go online — only when the path actually checks out.

• Paste, scan, or import to set up
• Swipe on Home to connect
• Green after a real reachability check
• Pick a faster location
• On device. No account. No node sales.
```

---

## zh-Hans · 简体中文

**名称** `Routeva 代理客户端`

**副标题** `粘贴已有订阅，一滑连接选节点`

**关键词**

```
加速,分流,规则,链接,导入,延迟,测速,工具,网络,隐私,隧道,配置,协议,线路,二维码,v2ray,vless,vmess,trojan,hysteria,vpn,reality,xray,ss
```

**宣传文本**

```
少走配置迷宫。粘贴已有订阅，上滑连接；绿灯表示这条路真的通了。我们不卖节点，也不需要注册。
```

**描述**

```
少走配置迷宫。

Routeva 是代理客户端，用你已经在付的订阅。粘贴链接，上滑连接；绿灯表示这条路真的通了，而不只是隧道亮了。

我们不卖节点。

粘贴。上滑。绿灯。
粘贴、扫码或导入你已有的订阅。在首页上滑。变绿，表示已经能经当前节点访问外网。

需要自己选的时候
• 按地区浏览并选更快的节点
• 测延迟，看哪条更稳
• Smart 跟随服务商规则
• Global 让流量都走节点
• 把某个域名钉成代理或直连
• 可自动更新当前订阅（能关掉）

路断了
可以换到其他节点，尽量不断线。失败用短提示，不丢一堆错误码。

你需要自备
你自己的订阅或节点。常见 YAML 与单节点链接可用（VLESS、VMess、Trojan、Shadowsocks、Hysteria2）。快慢、稳不稳、哪些网站能开，取决于服务商，不是 Routeva。

这不是 VPN 服务
没有我们的服务器。不用注册。没有广告。没有追踪。不承诺解锁流媒体。

数据默认只在这台设备上。第一次连接时，系统会请求 VPN 权限，以便流量走你的节点。

需要 iOS 17 或更高版本。

隐私政策：https://routeva.yilinglabs.com/privacy/
使用条款：https://routeva.yilinglabs.com/terms/
```

**更新说明**

```
欢迎使用 Routeva。

粘贴你已有的订阅，上滑连接；绿灯表示这条路真的通了。

• 粘贴、扫码或导入即可开始
• 首页上滑连接
• 可达性检查通过后才变绿
• 可选更快的节点
• 数据在设备上。不用注册。不卖节点。
```

---

## zh-Hant · 繁體中文（臺灣用詞）

**名稱** `Routeva 代理用戶端`

**副標題** `貼上既有訂閱，一滑連接選節點`

**關鍵字**

```
加速,分流,規則,連結,匯入,延遲,測速,工具,網路,隱私,隧道,設定,協定,線路,二維碼,v2ray,vless,vmess,trojan,hysteria,vpn,reality,xray,ss
```

**宣傳文字**

```
少走設定迷宮。貼上既有訂閱，上滑連接；綠燈表示這條路真的通了。我們不賣節點，也不需要註冊。
```

**描述**

```
少走設定迷宮。

Routeva 是代理用戶端，用你已經在付的訂閱。貼上連結，上滑連接；綠燈表示這條路真的通了，而不只是隧道亮了。

我們不賣節點。

貼上。上滑。綠燈。
貼上、掃碼或匯入你既有的訂閱。在首頁上滑。變綠，表示已經能經目前節點上網。

需要自己選的時候
• 依地區瀏覽並選更快的節點
• 測延遲，看哪條比較穩
• Smart 跟隨服務商規則
• Global 讓流量都走節點
• 把某個網域釘成代理或直連
• 可自動更新目前訂閱（能關掉）

路斷了
可以換到其他節點，盡量不斷線。失敗用短提示，不丟一堆錯誤碼。

你需要自備
你自己的訂閱或節點。常見 YAML 與單節點連結可用（VLESS、VMess、Trojan、Shadowsocks、Hysteria2）。快慢、穩不穩、哪些網站能開，取決於服務商，不是 Routeva。

這不是 VPN 服務
沒有我們的伺服器。不用註冊。沒有廣告。沒有追蹤。不承諾解鎖串流。

資料預設只在這台裝置上。第一次連接時，系統會請求 VPN 權限，以便流量走你的節點。

需要 iOS 17 或更新版本。

隱私權政策：https://routeva.yilinglabs.com/privacy/
使用條款：https://routeva.yilinglabs.com/terms/
```

**更新說明**

```
歡迎使用 Routeva。

貼上你既有的訂閱，上滑連接；綠燈表示這條路真的通了。

• 貼上、掃碼或匯入即可開始
• 首頁上滑連接
• 可達性檢查通過後才變綠
• 可選更快的節點
• 資料在裝置上。不用註冊。不賣節點。
```

---

## es · Spanish (Spain / Mexico 共用)

**Name** `Routeva Cliente Proxy`

**Subtitle** `Pega tu suscripción. Conecta.`

**Keywords**

```
vpn,v2ray,vless,vmess,trojan,shadowsocks,hysteria2,nodo,latencia,yaml,reality,xray,red,servidor,qr
```

**Promotional Text**

```
Conecta sin el laberinto. Pega el plan que ya tienes, desliza una vez y conéctate solo cuando la ruta se compruebe de verdad. No vendemos nodos.
```

**Description**

```
Conecta sin el laberinto.

Un cliente proxy para la suscripción que ya tienes. Pega un enlace, desliza una vez y conéctate solo cuando la ruta se compruebe de verdad.

No vendemos nodos.

Pega. Desliza. Verde.
Pega, escanea o importa un plan que ya pagas. Desliza en Inicio. El verde significa que llegas a través de tu nodo, no solo que hay un túnel vacío.

Cuando quieres decidir
• Recorre ubicaciones y elige un nodo más rápido
• Mide la latencia
• Smart sigue las reglas de tu proveedor
• Global envía todo por el nodo
• Fija un dominio a proxy o directo
• La actualización automática refresca el plan activo (puedes apagarla)

Si el camino cae
Routeva puede cambiar de nodo para que sigas online. Los fallos son cortos y claros.

Trae tu propio plan
Una suscripción o lista de nodos de un proveedor que tú eliges. Funcionan YAML habituales y enlaces de nodo (VLESS, VMess, Trojan, Shadowsocks, Hysteria2). Velocidad, estabilidad y qué sitios abren dependen de ese proveedor, no de Routeva.

No es un servicio VPN
Sin servidores nuestros. Sin cuenta. Sin anuncios. Sin rastreo. Sin promesas de desbloquear streaming.

Los datos se quedan en el dispositivo por defecto. La primera vez que conectas, iOS pide permiso de VPN para que el tráfico use tu nodo.

Requiere iOS 17 o posterior.

Privacidad: https://routeva.yilinglabs.com/privacy/
Términos: https://routeva.yilinglabs.com/terms/
```

**What’s New**

```
Te damos la bienvenida a Routeva.

Pega una suscripción que ya tienes, desliza una vez y conéctate — solo cuando la ruta se compruebe de verdad.

• Pega, escanea o importa para empezar
• Desliza en Inicio para conectar
• Verde después de una comprobación real
• Elige una ubicación más rápida
• En el dispositivo. Sin cuenta. Sin venta de nodos.
```

---

## pt-BR · Português (Brasil)

**Name** `Routeva Cliente Proxy`

**Subtitle** `Cole sua assinatura. Conecte.`

**Keywords**

```
vpn,v2ray,vless,vmess,trojan,shadowsocks,hysteria2,nodo,latencia,yaml,reality,xray,rede,servidor,qr
```

**Promotional Text**

```
Conecte sem o labirinto. Cole o plano que você já tem, deslize uma vez e fique online só quando o caminho for de verdade. Não vendemos nós.
```

**Description**

```
Conecte sem o labirinto.

Um cliente proxy para a assinatura que você já tem. Cole um link, deslize uma vez e fique online só quando o caminho for de verdade.

Não vendemos nós.

Cole. Deslize. Verde.
Cole, escaneie ou importe um plano que você já paga. Deslize na tela inicial. Verde significa que você alcança a internet pelo seu nó — não só que o túnel subiu.

Quando você quer escolher
• Percorra locais e escolha um nó mais rápido
• Teste a latência
• Smart segue as regras do seu provedor
• Global manda tudo pelo nó
• Fixe um domínio em proxy ou direto
• A atualização automática atualiza o plano ativo (você pode desligar)

Se o caminho cair
O Routeva pode trocar de nó para você continuar online. Falhas são curtas e honestas.

Traga o seu plano
Uma assinatura ou lista de nós de um provedor que você escolhe. YAML comuns e links de nó funcionam (VLESS, VMess, Trojan, Shadowsocks, Hysteria2). Velocidade, estabilidade e quais sites abrem dependem desse provedor — não do Routeva.

Não é um serviço de VPN
Sem servidores nossos. Sem conta. Sem anúncios. Sem rastreamento. Sem promessa de liberar streaming.

Os dados ficam no aparelho por padrão. Na primeira conexão, o iOS pede permissão de VPN para o tráfego usar o seu nó.

Requer iOS 17 ou posterior.

Privacidade: https://routeva.yilinglabs.com/privacy/
Termos: https://routeva.yilinglabs.com/terms/
```

**What’s New**

```
Bem-vindo ao Routeva.

Cole uma assinatura que você já tem, deslize uma vez e fique online — só quando o caminho for de verdade.

• Cole, escaneie ou importe para começar
• Deslize na tela inicial para conectar
• Verde depois de uma verificação real
• Escolha um local mais rápido
• No aparelho. Sem conta. Sem venda de nós.
```

---

## ja · 日本語

**Name** `Routeva プロキシクライアント`

**Subtitle** `購読を貼るだけ。ノードを選ぶ`

**Keywords**

```
vpn,v2ray,vless,vmess,trojan,shadowsocks,hysteria2,遅延,トンネル,yaml,スキャン,reality,xray,回線,サーバー,qr,ss
```

**プロモーションテキスト**

```
設定の迷路はいらない。すでにお持ちの購読リンクを貼り、一度スワイプ。経路が通ってからオンラインになります。ノードは販売しません。
```

**説明**

```
設定の迷路はいらない。

すでに契約しているプロキシ購読のためのクライアントです。リンクを貼り、一度スワイプ。経路が通ってからオンラインになります。

ノードは販売しません。

貼る。スワイプ。グリーン。
すでにお支払い中の購読を貼り付ける、QR で読み取る、またはファイルから読み込みます。ホームでスワイプ。グリーンは、トンネルが立っただけでなく、いまのノード経由で届いているということです。

自分で選びたいとき
• ロケーションから速いノードを選ぶ
• レイテンシを測る
• Smart はプロバイダのルールに従います
• Global はすべてをノード経由にします
• ドメインをプロキシまたはダイレクトに固定
• 利用中の購読を自動更新（オフにできます）

途切れたら
別のノードに切り替えて、できるだけつなぎます。失敗は短い表示だけです。

ご自身の契約が必要です
あなたが選んだプロバイダの購読またはノード一覧。一般的な YAML とノードリンク（VLESS、VMess、Trojan、Shadowsocks、Hysteria2）に対応します。速さ、安定、どのサイトが開くかはプロバイダ次第で、Routeva の約束ではありません。

VPN サービスではありません
当社のサーバーはありません。アカウント不要。広告なし。追跡なし。配信の解除は約束しません。

データは原則この端末だけにあります。初回接続時、iOS が VPN 許可を求めます。あなたのノードにトラフィックを通すためです。

iOS 17 以降が必要です。

プライバシー: https://routeva.yilinglabs.com/privacy/
利用規約: https://routeva.yilinglabs.com/terms/
```

**新機能**

```
Routeva へようこそ。

すでにお持ちの購読を貼り、一度スワイプ。経路が通ってからオンラインになります。

• 貼り付け、スキャン、読み込みで設定
• ホームでスワイプして接続
• 到達確認のあとでグリーン
• より速いロケーションを選べます
• 端末内。アカウント不要。ノード販売なし。
```

---

## ko · 한국어

**Name** `Routeva 프록시 클라이언트`

**Subtitle** `이미 있는 구독 링크로 바로 연결`

**Keywords**

```
vpn,v2ray,vless,vmess,trojan,shadowsocks,hysteria2,노드,지연,터널,yaml,스캔,reality,xray,서버,가져오기,qr
```

**프로모션 텍스트**

```
설정 미로 없이 연결. 이미 가진 구독 링크를 붙여넣고 한 번 쓸어 올리세요. 경로가 확인된 뒤에만 온라인입니다. 노드는 팔지 않습니다.
```

**설명**

```
설정 미로 없이 연결하세요.

이미 갖고 있는 구독을 위한 프록시 클라이언트입니다. 링크를 붙여넣고 한 번 쓸어 올리세요. 경로가 확인된 뒤에만 온라인이 됩니다.

노드는 팔지 않습니다.

붙여넣기. 스와이프. 초록.
이미 이용 중인 구독을 붙여넣거나 스캔, 가져오세요. 홈에서 쓸어 올리세요. 초록은 터널만 켜진 게 아니라, 현재 노드를 통해 실제로 닿았다는 뜻입니다.

직접 고르고 싶을 때
• 위치로 더 빠른 노드를 고릅니다
• 지연 시간을 측정합니다
• Smart는 제공자 규칙을 따릅니다
• Global은 모든 트래픽을 노드로 보냅니다
• 도메인을 프록시 또는 직행으로 고정합니다
• 사용 중인 구독을 자동 갱신합니다(끌 수 있습니다)

경로가 끊기면
다른 노드로 바꿔 가능한 한 연결을 유지합니다. 실패는 짧은 안내뿐입니다.

직접 준비한 요금제가 필요합니다
내가 고른 제공자의 구독 또는 노드 목록. 일반적인 YAML과 노드 링크(VLESS, VMess, Trojan, Shadowsocks, Hysteria2)를 씁니다. 속도, 안정성, 어떤 사이트가 열리는지는 제공자에게 달렸지 Routeva의 약속이 아닙니다.

VPN 서비스가 아닙니다
우리 서버 없음. 계정 없음. 광고 없음. 추적 없음. 스트리밍 잠금 해제를 약속하지 않습니다.

데이터는 기본적으로 이 기기에만 있습니다. 처음 연결할 때 iOS가 VPN 권한을 요청합니다. 트래픽이 내 노드를 쓰도록 하기 위해서입니다.

iOS 17 이상이 필요합니다.

개인정보 처리방침: https://routeva.yilinglabs.com/privacy/
이용약관: https://routeva.yilinglabs.com/terms/
```

**새로운 기능**

```
Routeva에 오신 것을 환영합니다.

이미 가진 구독을 붙여넣고 한 번 쓸어 올리세요. 경로가 확인된 뒤에만 온라인입니다.

• 붙여넣기, 스캔, 가져오기로 시작
• 홈에서 쓸어 올려 연결
• 실제 도달 확인 후 초록
• 더 빠른 위치를 고를 수 있습니다
• 기기 안. 계정 없음. 노드 판매 없음.
```

---

## de · Deutsch

Connect 会拦已被占用的商店名。不要填 `Routeva Proxy-Client` 或 `Routeva Network Proxy Client`。

**Name** `Routeva`

**Subtitle** `Proxy für dein eigenes Abo.`

**Keywords**

```
vpn,v2ray,vless,vmess,trojan,shadowsocks,hysteria2,knoten,latenz,tunnel,yaml,reality,xray,wischen
```

**Promotionstext**

```
Verbinden ohne Umwege. Eigenes Abo einfügen, einmal wischen — online erst, wenn der Weg wirklich steht. Wir verkaufen keine Knoten.
```

**Beschreibung**

```
Verbinden ohne Umwege.

Ein Proxy-Client für das Abo, das du schon hast. Link einfügen, einmal wischen — online erst, wenn der Weg wirklich steht.

Wir verkaufen keine Knoten.

Einfügen. Wischen. Grün.
Füge ein Abo ein, das du schon bezahlst — per Einfügen, Scan oder Import. Wische auf dem Home-Bildschirm. Grün heißt: Du erreichst das Netz über deinen Knoten — nicht nur, dass ein Tunnel steht.

Wenn du selbst wählen willst
• Standorte durchgehen und einen schnelleren Knoten wählen
• Latenz messen
• Smart folgt den Regeln deines Anbieters
• Global schickt alles über den Knoten
• Eine Domain auf Proxy oder Direkt festlegen
• Auto-Update hält das aktive Abo frisch (abschaltbar)

Wenn der Weg abbricht
Routeva kann den Knoten wechseln, damit du online bleibst. Fehler sind kurz und klar.

Bring dein eigenes Abo mit
Ein Abo oder eine Knotenliste von einem Anbieter, den du wählst. Gängige YAML-Dateien und Knoten-Links funktionieren (VLESS, VMess, Trojan, Shadowsocks, Hysteria2). Tempo, Stabilität und welche Seiten öffnen, hängen vom Anbieter ab — nicht von Routeva.

Kein VPN-Dienst
Keine Server von uns. Kein Konto. Keine Werbung. Kein Tracking. Kein Versprechen für Streaming-Freischaltung.

Daten bleiben standardmäßig auf dem Gerät. Beim ersten Verbinden fragt iOS nach der VPN-Erlaubnis, damit der Traffic deinen Knoten nutzen kann.

Erfordert iOS 17 oder neuer.

Datenschutz: https://routeva.yilinglabs.com/privacy/
Nutzungsbedingungen: https://routeva.yilinglabs.com/terms/
```

**Neuigkeiten**

```
Willkommen bei Routeva.

Eigenes Abo einfügen, einmal wischen — online erst, wenn der Weg wirklich steht.

• Einfügen, scannen oder importieren
• Auf Home wischen zum Verbinden
• Grün nach echter Erreichbarkeitsprüfung
• Schnelleren Standort wählen
• Auf dem Gerät. Kein Konto. Kein Knotenverkauf.
```

---

## 共用字段（不随语言变）

| 字段 | 填写 |
|---|---|
| **Privacy Policy URL** | `https://routeva.yilinglabs.com/privacy/` |
| **Privacy Choices URL** | 留空 |
| **Support URL** | `https://routeva.yilinglabs.com/privacy/#contact` |
| **Marketing URL** | `https://routeva.yilinglabs.com/` |
| **Copyright** | `2026 Yiling Labs` |
| **Primary Category** | **Utilities** |
| **Secondary Category** | Productivity |
| **Price** | Free |
| **Availability** | 先美国（及你实际要上的区）。中国大陆区同类审核风险高，不要默认全开。 |
| **Device** | iPhone only（`TARGETED_DEVICE_FAMILY = 1`） |
| **Minimum OS** | iOS 17.0 |
| **数据收集** | 否 · Data Not Collected |
| **IDFA** | No |
| **年龄分级** | 全 None/No · Unrestricted Web Access = No → **4+** |
| **DSA** | **此为交易 App** |
| **中国大陆 ICP / 越南游戏许可** | 不填 |
| **审核备注** | 只填英文一份，见下 |

联系：`privacy@yilinglabs.com`。电话填 Account Holder 能接到的号码。

法律页目前只有英文。8 语 listing 链同一 URL 可以提交；不要假装各语都有本地化政策正文。

---

## App Review 备注（英文 · 只此一份）

把 `REPLACE_WITH_DEMO_SUBSCRIPTION_URL` 换成审核员能打开的 HTTPS 订阅。没有这条，极易因 2.1 被拒。

```
Routeva is a proxy CLIENT. We do not operate VPN/proxy servers or sell nodes. The user pastes a subscription they already have.

NO ACCOUNT. No IAP in this version. No analytics, ads, crash SDK, or cloud assist.

HOW TO TEST
1. Launch Routeva. Welcome → Data & Privacy → Home (empty).
2. Tap Add subscription.
3. Paste this review-only subscription URL:

REPLACE_WITH_DEMO_SUBSCRIPTION_URL

4. Return to Home. Swipe down on the capsule to connect.
5. iOS will show the system VPN permission sheet. Please Allow — this is required so traffic can use the user’s node. Deny returns to Idle; that is expected.
6. Connected (green) means: system tunnel is up AND a reachability probe through the current node succeeded (HTTPS GET to https://routeva.yilinglabs.com/probe.txt). If the probe fails, the app returns to Idle with a short toast — it will not claim success from the VPN icon alone.

OTHER SURFACES
• Location: pick a node; Test measures entry latency.
• Settings: Routing mode (Smart / Global), domain exceptions, auto-update subscription, About.
• Domain exceptions may sync to the signed-in iCloud private database (user’s Apple ID). We cannot read other users’ private CloudKit data.
• Camera is used only if you choose Scan QR to import. Optional.

PRIVACY
App Privacy answers: Data Not Collected. Policy: https://routeva.yilinglabs.com/privacy/

If the demo subscription is unreachable from the review network, please try again later or contact privacy@yilinglabs.com. A screen recording of a successful connect can be attached on request.
```

---

## 截图

`gtm/stores/app_store/screenshots/` · 仅 English · 6.7" 与 6.5" 各 4 张，顺序：

1. Connect without / the maze.  
2. Swipe once / to go online.  
3. Paste a link / to set up.  
4. Pick the / fastest one.

---

## 提交前自检

- [ ] 8 语名称/副标题/关键词未写竞品名、未写「科学上网 / 翻牆」  
- [ ] 每语描述前三行写清「自备订阅 / 不卖节点」  
- [ ] 未宣称 Help、Repair、流媒体解锁、协议 100% 可用  
- [ ] 线上 Privacy / Terms 已与「本版无云辅助、不收集」对齐  
- [ ] 审核备注里的演示订阅在审核窗口内能连上  
- [ ] App Privacy = 不收集 · DSA = 交易 App  
- [ ] 桌面名仍是 Routeva · 截图仍是英文套  
