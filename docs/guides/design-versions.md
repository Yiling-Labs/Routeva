# 设计多版本管理（L2）

> 适用于 AI 陆续生成多风格原型/高保真、再挑选采用的工作流。  
> 结构规则见 [design/AGENTS.md](../../design/AGENTS.md)。

## 为什么

若把所有版本平铺在 `hi-fi/`，目录会迅速不可用；Agent 也不知道该实现哪一套。

## 规则摘要

| 规则 | 做法 |
|---|---|
| 双轨 | `_explore/` 探索；`current/` 采用 |
| 批次名 | `YYYY-MM-DD-<style-slug>` |
| 批内结构 | `<flow>/{nn}-{screen}[--state].ext` |
| 晋升 | **复制** flow → current；保留 explore |
| 标记 | batch 内 `STATUS.md` |
| 粒度 | 默认 **按 flow** |
| gtm | **只从 current 导出** |
| git | explore + current 都进仓；图片建议 LFS |

## STATUS.md 最小字段

```markdown
# status: selected | rejected | superseded | exploring
# date: YYYY-MM-DD
# flows_promoted: onboarding, home   # 若 selected
# notes: 一句话为何（可选）
# current_paths: design/hi-fi/current/onboarding/
```

## 检查清单

- [ ] 新探索是否建了新 batch，而不是覆盖 current？  
- [ ] 选定后是否复制到 current 并写 STATUS？  
- [ ] 实现是否只读 current？  
- [ ] 上架图是否来自 current 而非 explore？  
- [ ] 文件名是否避免 final/new2？  

## 非目标

- 规定具体视觉风格或组件库  
- 替代 Figma 等工具本身的版本历史（本规则管**工作区落盘**）  
