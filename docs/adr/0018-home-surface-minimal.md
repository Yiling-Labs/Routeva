# Home Surface：极简中部 + pin 连接手势

Home **无底部 Tab**；根画布 = 连接。中部只保留连接真值与选节点相关信息；规则说明、不卖节点口号、VERIFIED/probe 叠词、默认 Auto、模式三选一不进 Home。

**连接故事（权威 hi-fi：`design/hi-fi/current/craft-p0/02-home.html`）：**  
Idle（黑、无点、START 顶）→ 下滑约 ⅓（1 圈点亮）→ 约 ⅔（2 圈）→ Connecting（3 圈全亮 + Connecting…，仍黑场）→ Connection Success（**绿场** + 时长/速率 + Connected）。断开：上滑 STOP → 回 Idle。

**选节点：** 国旗 Cover Flow；**标题用节点名**（非国家名）+ **弱化协议标注**（如 `· VMess`）。**Idle / Can’t connect：** Cover Flow 下节点名行 + 弱 › **可点 → Location**（无中部空 *Location ›* pill；中部仅主状态）。**Swipe / Connecting：** 节点名行锁定。**Connected：** 绿场中部节点行可点（见 ADR **0056**）。Cover Flow 横滑 = 临时焦点；Location 点选 = Preferred。

**为何：** 日常关心「连没连上、走哪条节点」；点阵绑定连接过程而非 Idle 装饰；绿场 = Probe 成功真值，禁止假绿。模式切换低频，进 Settings/Agent。

**后果：** 实现与 hi-fi 以本 ADR + CONTEXT **Home Surface / Home Mid Copy / Connect Gesture** 为准。Diagnostic/Repair 等屏仍 sheet，视觉可后补。

**顶栏出口：** 见 **ADR 0020**（Agent · Subscriptions · Settings；Activity 降级；Empty 隐藏 Subscriptions）。
