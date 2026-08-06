# User Override：iOS iCloud 备份（MVP 例外）

修订 **Identity** 的一刀切「多设备/iCloud 不在 MVP」：**仅 User Override** 在 **iOS** 上经**用户 iCloud** 做静默备份；主职是换机/重装带走例外列表，**不是**全量配置同步，也**不是**多设备实时同步 SLA。Android 为 **Platform Gap**（本机-only）。订阅 / Token / Mode / DNS / 快照 / 诊断历史上云一律不做。

**为何只做 Override：** 用户自建例外最不可「再粘贴一次订阅」恢复；体量小、无 Token，隐私与合规成本低于整包配置。与「无自建账号」一致——跟系统 Apple ID，不引入 Routeva 账户。

**语义（备份为主 + 有限合并）：**

| 本机 | iCloud | 行为 |
|------|--------|------|
| 空 | 有数据 | 整表恢复；成功可一次短 toast；失败弱提示 |
| 非空 | 不一致 | 按 Domain 合并后写回本机与 iCloud |
| 任意 | 不可用 | 安静本机-only；**仅**空库恢复失败提示 |

- 同 Domain 冲突：条目标 `updatedAt` 较新者**整条**胜出（含 proxy|direct 与 enabled）；并列或缺失 → 本机胜。  
- 删除：带时间戳**墓碑**进 iCloud，合并时防旧列表复活。  
- 触发读：冷启动/回前台、进入 Overrides。写：本机每次 Override 成功变更后静默整表（含墓碑）upsert。  
- 恢复/合并后尽快作用于当前分流（与手改同源）。  
- **不**记 Activity；**无** Settings 主开关/常驻云状态；Privacy/About 一句披露。

**刻意不选：** 真·多设备实时同步；非空时 iCloud 整表覆盖本机；无墓碑并集；双端（Android）同期等价云；自建后端存 Override。

**后果：** CONTEXT **Identity** / **User Override Rule** / **User Override iCloud Backup**；PRD Out of scope 与 §4.7 / 验收收紧表述；实现期选 CloudKit 或等价 iCloud API 为工程细节，不另改产品语义。
