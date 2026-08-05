# Repair 须一键确认，禁止静默自动修

判为 Client-Fixable 后，系统不得默认静默执行 Repair。用户须在诊断卡（或 Agent 中等价的明确「执行修复」意图）确认一次，方可进入该次 Repair 流程。一次确认可覆盖流程内多个 Allowlist 候选（有上限）；过程可取消；失败则回滚到进入前 Config Snapshot。MVP 不以「永远自动修复」总开关为默认。

**Considered Options**
- 静默自动修 → 与「不得在用户不知情时改系统/配置」冲突，VPN 类信任风险高。
- Onboarding 总同意后永久自动修 → 叙事与撤销成本高，不作 MVP 默认。
- **选定：** 每次 Repair 流程一键确认。
