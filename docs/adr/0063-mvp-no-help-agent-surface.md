# MVP 不含 Help / Agent 面（诊断·Repair UI 一并后置）

## 状态

Accepted · 2026-08-07  

## 上下文

Routeva 原 MVP 含 Thick Agent（用户可见 **Help**）、Diagnostic Engine 展示与 Repair 流（多经 Help 触发 · ADR 0060）。实现与设计带宽下，决定 **暂不** 把 Help 做进首版可交付范围，先证明 **Table Stakes Connect**。

## 决策

1. **MVP 不含：**  
   - **Help / Agent Surface**（顶栏 Help pill、聊天、信任条、What Help can do、Cloud AI 开关）  
   - **诊断结果 UI**（四桶 sheet / 过程卡）与 **Repair 确认/进度 UI**  
   - 以 Help 为入口的一切用户可见自愈交互  

2. **MVP 仍含：**  
   - 导入、连接、Probe、Location / Preferred、Mode / DNS / Overrides、Subscriptions、失败 Idle+toast、Failover toast、Activity **本机记录**（**无**用户可见列表）  
   - 领域模型中 Diagnostic Engine / Failure Bucket / Repair Allowlist 等术语可保留为 **Post-MVP** 规格，**不**作为 MVP 验收 UI  

3. **Home Chrome（MVP）：**  
   - 有订阅：`[ Subscriptions ] …… [ Settings ]`  
   - Empty：`[ Settings ]`  only（**无** Help）  

4. **失败路径（MVP）：** 维持 ADR **0059**（Idle + toast）。**无**自动诊断 sheet；**无** Help 入口。用户再连或检查订阅/网络。  

5. **相对旧 ADR：**  
   - **0060**（仅 Help 触发诊断）在 MVP **无触发面** → 诊断 UI 整段 **Post-MVP**  
   - **0035–0044、0042** 等 Help/Agent 决策 **保留作 Post-MVP**，不删史；MVP 范围以本 ADR 为准  
   - Product Bet 的 **Self-Healing Loop 完整证明** 移到 **Post-MVP**；MVP 主证明 = **稳定连上 + 诚实失败反馈（toast）**  

6. **hi-fi：** `06-agent` / `07-diagnostic` 移出 craft-p0 **current 权威**（进 `_explore` 或标注 post-MVP）；`02-home` / `03-setup` 去掉 Help pill。  

## 为何

Help / Agent / Repair 交互未收口且成本高；先 iOS 真机证明连接闭环（ADR 0061）。避免半截 Help 进 Beta。

## 后果

- PRODUCT / PRD / CONTEXT / checklist / copy acceptance 以本 ADR 裁 MVP  
- 日后加回 Help 须：恢复入口 + 诊断触发 + Craft；可新开 ADR 或修订本条  

## 非决策

- Post-MVP 时诊断是否仍「仅 Help」还是部分自动  
- Help 发现路径（grill 搁置项）  
