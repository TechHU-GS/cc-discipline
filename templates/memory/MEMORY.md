# 项目工作纪律（cc-discipline 框架）

本项目已安装 cc-discipline 纪律框架，新对话开始时请注意以下要点。

## 三层防线
1. **Rules**（`.claude/rules/`）— 按文件路径自动注入，编辑源码时会出现检查清单
2. **Hooks**（`.claude/hooks/`）— 编辑前/执行后自动运行，可阻止操作（exit 2）
3. **Agents**（`.claude/agents/`）— reviewer 审查方案、investigator 隔离调研

## Hook 行为
- `pre-edit-guard.sh` — 有未验证假设时**阻止编辑源码**，先更新 docs/debug-log.md
- `streak-breaker.sh` — 同文件编辑 ≥3 次警告，≥5 次**硬停止**
- `post-error-remind.sh` — 检测到错误输出时注入调试流程提醒（通过 exit 2 反馈给你）

## 关键文件
- `docs/progress.md` — 进度记录，每个里程碑更新，compact 后第一件事读它
- `docs/debug-log.md` — 调试日志，假设标记"待验证"/"已确认"，影响 pre-edit-guard

## 核心纪律
- 先理解再动手，不锁定第一个解释（≥2 个替代假设）
- 连续 3 次失败 → 停下来汇报
- 不要打地鼠 — 同一文件反复改说明没找到根因
- 调试四阶段：收集 → 假设 → 验证 → 修复，禁止跳步
