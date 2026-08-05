# Settings 根页不设 History 段

Settings 根页分组改为两段：**Connection → App**。**去掉** 根页 **History**（不再有 **Activity ›** / **Snapshots ›** 两行）。

**为何：** Activity / Snapshots 对小白与多数半专业**无直接日常场景**；根页两行像系统日志与配置时光机，发现成本高、解释成本高。可解释与可回滚仍靠**机制 + 失败路径触点**，不靠 Settings 常驻审计入口。

**能力保留（入口下沉）：**
- **Activity（能力仍 P0）：** 本机仍记事件；用户可见触点优先 **Help / Agent 最近事件摘要**、诊断/Repair 结果上下文；**不**要求 Settings 根页或 History 二级列表作主入口。完整时间线 UI 可 P1 / 后补。
- **Config Snapshot（机制仍在）：** 变更前/Repair 前按 Snapshot Policy 建快照；**用户主动回滚**主路径在 **Repair 确认/失败/完成** 与相关确认 UI，**不**要求 Settings 快照列表作主入口。

**相对：** 废止根页呈现 ADR **0024**；**0022** 三段改为两段；**0013** 入口从「Settings 二级」改为失败路径 / Help 优先。

**后果：** CONTEXT **Settings Surface** / **Activity Log**；hi-fi `05-settings.html` 根页无 History；`00-ia` ST-0 仅 Connection + App。
