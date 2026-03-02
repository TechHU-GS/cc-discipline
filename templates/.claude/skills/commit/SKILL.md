---
name: commit
description: 智能提交 — 测试、更新文档和记忆、然后提交，确保知识不随 commit 丢失
disable-model-invocation: true
---

按以下流程执行智能提交，核心原则：**代码和知识一起提交**。

## 1. 运行测试

查看 CLAUDE.md 中的测试命令并执行。测试失败则停止提交并报告。
没有配置测试命令的项目跳过此步。

## 2. 更新知识文件

依次检查是否需要更新（简单改动可跳过）：

**docs/progress.md** — 本次改动是否构成里程碑或重要进展？是则追加记录。

**docs/debug-log.md** — 是否有调试会话需要关闭或更新状态？

**CLAUDE.md** — 是否有新的组件、接口、已知陷阱、架构变更需要同步？

**Auto Memory** — 是否有跨会话值得记住的经验教训？（bug 模式、API 陷阱、调试技巧）
更新 memory 文件，保持 MEMORY.md 200 行以内。

## 3. 执行 git commit

```
git status
git diff --staged && git diff
git log --oneline -5
```

- 选择性 `git add`（不要 `git add -A`）
- docs/ 和 CLAUDE.md 如有变更一并提交
- 不要提交 .env、credentials 等敏感文件
- 提交消息格式参考已有 commit 风格
- 不要 push（除非用户明确要求）
- pre-commit hook 失败时修复后创建新 commit（不要 --amend）
