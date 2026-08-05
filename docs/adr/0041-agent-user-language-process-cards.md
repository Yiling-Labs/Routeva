# Agent 过程卡用用户语言，不暴露内部术语

Help 对话中的诊断/工具过程卡对用户展示 **意图句 + 四桶白话**（App can fix / Provider / Your network / Not sure），不展示 *Diagnostic Engine*、*Client-Fixable* 等内部名。可弱注与全 app 同一套检查。实现与日志仍用引擎术语。

**为何：** Connection Help 面向不懂协议的用户；过程可解释 ≠ 暴露架构名。

**后果：** 见 CONTEXT **Agent Surface**；hi-fi `06-agent.html` chat 帧对齐。
