# 实现任务 · Subscriptions 刷新 UI 态（验收 1d / 1e）

| 元数据 | |
|---|---|
| **状态** | open |
| **来源** | grill 0015 · hi-fi `04-subscriptions` 帧 **1d / 1e** · [`acceptance-by-screen.md`](../../copy/acceptance-by-screen.md) §3 |
| **权威** | CONTEXT **Subscription Refresh** · ADR **0015** · `en.yaml` |
| **平台** | Dual-Native：`app/ios/` + `app/android/`（各端对等交付，可并行） |
| **依赖** | Active Subscription 模型；订阅是否「可远程刷新」的领域标志；手动 Update 网络路径 |

设计文案验收（对照 hi-fi / keys）与本文件 **实现任务** 分离：本文件 = 编码与测试 DoD。

---

## IMPL-SUB-1d · Not remote-refreshable（无远程源）

**用户可见：** Active 为单节点 URI / 无复访 URL 的本地文件等时，**不**展示可点主 CTA *Update*；展示不可更新说明。

### 范围

| 做 | 不做 |
|---|---|
| 领域模型区分 `remoteRefreshable`（或等价）：有可复访订阅 URL 才为 true | 假装 Update 成功或静默 no-op 却仍显示 *Update* |
| Active 且 `!remoteRefreshable`：主按钮区改为说明块 | 自动刷新路径对该 Active 发网络请求 |
| 文案绑定 `subs.update.unavailable` + `subs.update.unavailable.hint` | 在此态展示 *Updating…* busy |
| 非 Active 行行为不变（无 Update 主 CTA 即可） | 改 Settings Auto-update 总闸逻辑（另任务） |

### 验收 DoD

- [ ] **iOS / Android：** 导入仅单节点 URI（或等价无 URL）并设为 Active → 列表 **无** 可点 *Update*；可见 *Can’t update automatically* + hint  
- [ ] **iOS / Android：** 有远程 URL 的 Active → 仍显示 *Update*（与帧 1 / 1c 一致）  
- [ ] 文案来自 `en.yaml` 灌入（无硬编码英文字面漂移）  
- [ ] 自动刷新（闸开 + 冷启动）对该 Active **不发起** 拉取；可静默 skip（ADR 0015）  
- [ ] 对照 hi-fi 帧 **1d**；acceptance §3 **1d** 文案走查可勾  

### Keys

- `subs.update.unavailable`  
- `subs.update.unavailable.hint`  

### 参考

- hi-fi：`design/hi-fi/current/craft-p0/04-subscriptions.html` · variant `local`  
- ADR 0015 · CONTEXT Subscription Refresh  

---

## IMPL-SUB-1e · Manual Update failed（仅手动失败）

**用户可见：** 用户点 *Update* 且拉取失败时，短 **toast**（*Couldn’t update. Check your connection and try again.*，**2–3s** 自动消失，与导入成功 / iCloud restore toast 同模式）；*Update* 仍可再点；**不**覆盖旧节点/规则；**无**卡内错误条。

### 范围

| 做 | 不做 |
|---|---|
| 手动 Update 失败 → 顶部短 toast（非全屏、非卡内横幅） | 自动刷新失败弹同等 Toast（自动路径保持安静） |
| 文案仅 `subs.update.failed`（单行） | 失败时用新空配置覆盖旧配置 |
| 主 CTA 仍为 *Update*（可重试）；busy 用 `subs.updating` | 常驻错误条 / `subs.update.failed.hint` 副文 |
| 成功 → 更新 *Updated* / meta（无失败 toast 残留） | 把 Provider 失败强行塞进诊断四桶（除非用户另走连接失败路径） |

### 验收 DoD

- [ ] **iOS / Android：** 模拟/桩：远程返回失败或无网 → 保留旧节点表；短 toast *Couldn’t update. Check your connection and try again.*（约 2–3s 消失）；*Update* 可再点  
- [ ] **iOS / Android：** 重试成功 → 节点/规则/*Updated* 更新；无卡内错误 UI  
- [ ] 自动刷新失败 **不** 走本 UI 态（无 1e toast、无成功 Toast）  
- [ ] 文案来自 `en.yaml`  
- [ ] 对照 hi-fi 帧 **1e**；acceptance §3 **1e** 文案走查可勾  

### Keys

- `subs.update.failed`（toast 正文）  
- `subs.update` · `subs.updating`（重试 / busy）  

### 参考

- hi-fi：`04-subscriptions.html` · variant `failed`（`SubToast`）  
- visual-system：**Toast** 2–3s · `role="status"`  
- ADR 0015 · PRD §4.1 Subscription Refresh  

---

## 建议实现顺序

1. **领域标志** `remoteRefreshable`（导入时写入，随成功远程刷新保持）  
2. **IMPL-SUB-1d** UI 分支（无网络依赖，可先合）  
3. 手动 Update 管道错误映射 → **IMPL-SUB-1e**  
4. 双端 UI 测试 / 手工走查勾 acceptance  

---

## 完成定义（整包）

- [ ] IMPL-SUB-1d 双端 DoD 全勾  
- [ ] IMPL-SUB-1e 双端 DoD 全勾  
- [ ] `docs/copy/acceptance-by-screen.md` §3 **1d / 1e** 文案 ☑ 勾上  
- [ ] 本文件 **状态** → `done`，并在 sessions 记一笔关闭日期  
