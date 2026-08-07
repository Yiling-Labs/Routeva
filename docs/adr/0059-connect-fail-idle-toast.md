# 连接失败 = Idle + 短 toast（无 Can’t connect 主状态）

连接未达 Connection Success 时：Home **立即回到 Idle** 中部 *Not Connected*（与未尝试连接同一黑场骨架），并展示 **短 toast**（约 2–3s，如 *Couldn’t connect. Try again.*）。**不再**使用常驻主状态 *Can’t connect*。

**相对先前：** 收紧 Home Mid Copy；失败反馈不占中部第二状态。用户可立刻再下滑连接。  
**诊断：** 不自动跑、不自动弹（ADR **0060**）；用户点 **Help** 后再触发 Engine。

**权威 hi-fi：** `design/hi-fi/current/craft-p0/02-home.html` 帧 **C1 · Connect failed**（Idle + fail toast）。文案：`home.connect.failed.toast`。

**后果：** CONTEXT **Home Mid Copy** · **Diagnostic Trigger** · ADR **0060**。
