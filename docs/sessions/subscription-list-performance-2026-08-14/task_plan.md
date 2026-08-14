# Task Plan: 订阅列表性能优化

## Goal
消除六七个以上订阅时列表进入、滚动和 Set Active 切换的明显卡顿，同时保持当前节点与连接状态逻辑正确。

## Current Phase
完成

### Phase 1: 定位渲染与切换热点
- [x] 找到订阅列表页面和每行派生数据
- [x] 找到 Set Active 的数据库、配置与测速链路
- [x] 检查并行工作区改动边界
- **Status:** complete

### Phase 2: 方案
- [x] 区分主线程 I/O、重复计算和动画过载
- [x] 设计最小且可验证的优化
- **Status:** complete

### Phase 3: 实现
- [x] 优化列表数据快照/惰性渲染
- [x] 优化 Set Active 更新与动画
- [x] 保留并行改动
- **Status:** complete

### Phase 4: 轻量验证
- [x] 语法与 diff 检查
- [x] 相关最小专项测试或编译证据
- **Status:** complete

### Phase 5: 交付
- [x] 汇总根因、改动和剩余完整构建/安装步骤
- **Status:** complete

## Decisions
- 不先假设“节点多”就是唯一原因，以代码调用频率和主线程工作量为依据。
- 不在未获本轮确认时执行完整 Xcode 构建或真机安装。
- 根目录规划文件属于另一并行任务，本任务使用独立 session 目录。

## Errors
- 暂无。
