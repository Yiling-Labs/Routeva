# 诊断仅在用户进入 Help（Agent）后触发

**Diagnostic Engine 不在日常连/断/导入失败路径自动跑、也不自动弹诊断 UI。**  
用户点顶栏 **Help**（内部 Agent）进入 **Agent Surface** 后，才运行诊断（或由 Help 内明确意图触发同一 Engine）。失败日常反馈 = **短 toast + 回 Idle**（ADR **0059**），避免异常/噪声触发导致体验差。

**相对 ADR 0008：** 0008 的「失败路径自动运行并展示」在 **UI 与强制 Engine 跑** 上由本 ADR **取代**。Engine 仍是唯一故障裁判；Agent/Help **必须**调用同一 Engine，不得平行判定。

**为何：** 自动诊断易误触发、打断「连上即用」；用户主动求助时再深度检查，噪声更低、意图更明。

**后果：** CONTEXT **Diagnostic Trigger**；PRD §4 触发条款；实现勿在 connect fail 默认 `runDiagnostic()`；Help 空态/对话可启动检查。
