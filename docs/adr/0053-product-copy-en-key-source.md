# App UI 文案：English 键值源在 docs/copy，不预译 8 语

**不**在写代码前准备 7 语机翻齐套。App 用户可见串的工程前置是 **English 源 + 稳定 key**（`docs/copy/en.yaml`），覆盖 **P0 闭集 + 壳层骨架**；机翻仍按 ADR **0047**（T1 壳层）在 **键稳定 / 伪本地化抽检之后、上架前** 对 `tier: shell` 批量执行；`tier: lock-en` 不硬译。

**落盘与形态：** `docs/copy/en.yaml`（键值就绪）+ `docs/copy/README.md`（治理 only）。**不**进 `app/`（设计定稿前无应用实现）、**不**进 `gtm/`（商店物料另计）、**不**提前维护 xcstrings/xml 双份。Key 用 `surface.slot`；Android 灌入时 `.` → `_`。

**权威分轨：** `lock-en`（诊断主文案/四桶、Repair、隐私关键句、付费墙等）以 CONTEXT / ADR 为准；`shell` 以 current hi-fi 收编/微调。清单是投影，不是第三套产品真理。

**生命周期：** 开工前种子填满 P0+壳 → 实现期改用户可见 English **先改 en.yaml 再灌双端** → 上架前 shell 机翻。首版填充：**收编**权威闭集句 + **壳层补齐**中性通用键；禁止临场创作 lock-en。

**为何：** Dual-Native 需要单一 English 防漂移；预译 8 语会在 Craft 未稳时反复作废，且与 0047「诊断/同意锁 en」冲突。键值就绪已够开发直接建 String Catalog。

**后果：** 见 CONTEXT **Product Copy Source**；locale 闭集与机翻策略仍以 **0047 / 0048** 为准。GTM 与营销站长文不进本表。
