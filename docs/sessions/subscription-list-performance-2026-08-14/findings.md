# Findings

## Requirements
- 订阅达到约 6–7 个时，进入订阅列表、滚动列表、切换 Active 都应保持流畅。
- 节点数量较多时不能在 SwiftUI 每次刷新中反复进行数据库或高成本聚合。

## Findings
- 订阅列表已经使用 `LazyVStack`，卡顿并非简单地由一次性创建全部卡片造成。
- `SubscriptionSummary` 为每个订阅携带完整 `[NodeSummary]`；列表本身只展示节点数量，但仍复制、比较并发布所有节点配置。
- `reloadSubscriptions()` 会按订阅逐个查询节点（N+1 查询），随后在主线程映射全部节点；切换活动订阅时也会完整执行一次。
- 列表直接观察整个 `RoutevaAppModel`，延迟测试、流量、连接状态等无关 `@Published` 更新也会触发列表和卡片重新求值。
- 整个 `LazyVStack` 对活动订阅 ID 变化应用隐式动画。活动卡片和普通卡片高度不同，切换时所有行都会参与重新布局动画，形成明显的“PPT 式”移动。
- 真正需要完整节点数组的只有当前活动订阅；非活动订阅在列表中只需要节点总数。

## Optimization Direction
- 为订阅摘要增加独立 `nodeCount`，非活动订阅不再加载完整节点数组。
- 数据库一次获取所有订阅的节点计数，只额外读取活动订阅的完整节点，消除 N+1 节点加载。
- 移除整张列表的隐式布局动画，仅保留必要的局部状态表现。
- 让订阅卡片按输入做等值跳过，避免模型中无关状态更新时重复绘制昂贵的玻璃、渐变和阴影层。

## Workspace Boundary
- `SubscriptionViews.swift` 与 `RoutevaDatabase.swift` 当前无已有工作区修改。
- `AppModel.swift` 存在其他任务的测速/协议支持改动，但本任务目标区域 `reloadSubscriptions()` 与 `SubscriptionSummary` 尚未被修改；仅在这两个局部做最小补丁。
- 数据库是 actor，GRDB 读取不占用主 actor；当前主要主线程成本是完整节点摘要映射、巨型值发布及 SwiftUI diff/布局。

## Safety Checks
- 代码中只有活动订阅通过 `activeSubscription.nodes` / `availableNodes` 消费节点详情；非活动订阅的节点数组仅被列表拿来显示 `.count`，可以安全替换为独立计数。
- `SubscriptionSummary` 只有 `reloadSubscriptions()` 一个构造点，模型调整的影响范围可控。
- 将订阅记录、分组计数与活动节点放在同一次 GRDB 只读快照中，可同时减少 actor 往返和避免跨查询状态不一致。

## Files
- `app/ios/Sources/RoutevaApp/SubscriptionViews.swift`
- `app/ios/Sources/RoutevaApp/AppModel.swift`
- `app/ios/Sources/DataKit/RoutevaDatabase.swift`
