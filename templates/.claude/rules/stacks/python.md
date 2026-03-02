---
globs: "**/*.py,**/pyproject.toml,**/setup.py,**/requirements*.txt"
description: "Python 规则 — 编辑 Python 文件时自动注入"
---

## Python 工作纪律

### 代码质量
- 修改后运行 lint/type check（项目配了什么就用什么：ruff, mypy, pyright 等）
- 类型标注：新代码必须有 type hints，修改旧代码时顺手补上
- import 排序遵循项目约定（通常 isort 或 ruff 管理）

### 依赖管理
- 添加新依赖前先问 — 是否真的需要？有没有标准库替代？
- 确认依赖版本约束 — 不要无约束 pin，也不要 pin 太死

### 测试
- 修改逻辑后必须跑相关测试
- 先确认项目用什么测试框架（pytest? unittest?）和运行命令，不要假设
- 测试失败时不要改测试来通过 — 先确认是测试过时还是代码有 bug

### 禁止事项
- 禁止裸 `except:` 或 `except Exception:` 吞掉所有异常
- 禁止在不理解现有代码的情况下整个重写一个模块
- 禁止引入 `os.system()` — 用 `subprocess.run()` 并处理错误
