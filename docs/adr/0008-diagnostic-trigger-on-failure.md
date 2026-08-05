# 诊断在失败路径自动运行

Diagnostic Engine 在失败路径**自动**运行并展示 Failure Bucket，不在每次成功连接后强制完整体检。自动触发至少包括：导入无法完成、未能达到 Connection Success（含 Connectivity Probe 失败）、连接中断且自动恢复失败。用户与 Agent 可手动重跑；Agent 必须使用同一 Engine。成功路径保持安静。

**Considered Options**
- 每次连接后总检 → 噪声大、耗电，削弱「连上即用」体感。
- 仅手动诊断 → 削弱 Self-Healing，失败时易只剩系统错误码。
- **选定：** 失败才自动诊断。
