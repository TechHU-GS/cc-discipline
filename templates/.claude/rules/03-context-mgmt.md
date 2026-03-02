---
globs: "**/*"
description: "上下文管理纪律 — 防止 compact 丢失关键信息"
---

## 上下文管理

### 主动检查点
- 每完成一个里程碑 → 更新 `docs/progress.md`（当前状态、关键决策、下一步）
- 调试过程中 → 更新 `docs/debug-log.md`（假设、证据、排除结果）
- 做出架构决策时 → 记录决策和原因，写入 progress.md

### 调研隔离
- 需要大量读取代码库时 → 使用子代理，不要在主对话中读大量文件
- 子代理返回摘要后，在主对话中基于摘要决策

### Compact 策略
- 如果 context 即将满 → 主动提醒用户
- compact 前确保 progress.md 是最新的
- compact 后第一件事：读取 `docs/progress.md` 恢复上下文

### 禁止事项
- 禁止在 context 接近满时开始新的大任务
- 禁止在一个对话里混合不相关的任务
