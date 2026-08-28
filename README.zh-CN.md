# cc-discipline

**Claude Code 项目纪律框架** — 让 AI 编码助手在复杂任务中保持专注和纪律。

解决 Claude Code 在长对话、复杂任务中常见的问题：
- 🎯 思路跑偏、丢失主线目标
- 🔨 打地鼠式修补症状
- ⚡ 急于锁定第一个解释
- 🧠 compact 后丢失关键上下文和原则
- 🔄 反复犯同样的错误

## 架构：三层防线

```
┌─────────────────────────────────────────┐
│  Layer 3: Subagents（独立判断）          │
│  reviewer — 独立 context 审查方案       │
│  investigator — 隔离调研不污染主对话    │
├─────────────────────────────────────────┤
│  Layer 2: Hooks（代码强制）             │
│  pre-edit-guard — 编辑前检查纪律       │
│  streak-breaker — 检测打地鼠模式       │
│  post-error-remind — 错误后提醒流程    │
├─────────────────────────────────────────┤
│  Layer 1: Rules（自动注入）             │
│  core-principles — 核心原则            │
│  debugging — 调试纪律                  │
│  before-edit — 修改前检查              │
│  context-mgmt — 上下文管理             │
│  no-mole-whacking — 反打地鼠           │
│  stacks/* — 技术栈特有规则             │
├─────────────────────────────────────────┤
│  Foundation: CLAUDE.md + docs/          │
│  项目信息 + 进度记录 + 调试日志         │
└─────────────────────────────────────────┘
```

**Rules** = 贴在它眼前（自动注入，按路径触发）  
**Hooks** = 锁住它的手（代码级强制，可阻止操作）  
**Subagents** = 派人盯着它（独立 context 审查，不被主对话惯性影响）

## 快速开始

### 方法 1: 克隆 + 初始化脚本

```bash
git clone https://github.com/TechHU-GS/cc-discipline.git ~/.cc-discipline

# In your project directory:
cd your-project
bash ~/.cc-discipline/init.sh
```

### 方法 2: GitHub Template

1. 点击本仓库的 **Use this template** 按钮
2. 创建新项目后，编辑 `CLAUDE.md` 填写项目信息

### 方法 3: 只安装全局规则

```bash
git clone https://github.com/TechHU-GS/cc-discipline.git /tmp/cc-discipline
cp /tmp/cc-discipline/global/CLAUDE.md ~/.claude/CLAUDE.md
```

## 文件结构

```
your-project/
├── CLAUDE.md                          # 项目特有信息（你维护）
├── .claude/
│   ├── settings.json                  # Hooks 配置
│   ├── rules/
│   │   ├── 00-core-principles.md      # 核心工作原则
│   │   ├── 01-debugging.md            # 调试纪律
│   │   ├── 02-before-edit.md          # 修改前检查
│   │   ├── 03-context-mgmt.md         # 上下文管理
│   │   ├── 04-no-mole-whacking.md     # 反打地鼠
│   │   └── stacks/                    # 技术栈特有规则
│   │       ├── rtl.md                 #   RTL / IC 设计
│   │       ├── embedded.md            #   嵌入式 C/C++
│   │       ├── python.md              #   Python
│   │       ├── js-ts.md               #   JavaScript/TypeScript
│   │       └── mobile.md              #   移动端
│   ├── hooks/
│   │   ├── pre-edit-guard.sh          # 编辑前纪律检查
│   │   ├── streak-breaker.sh          # 打地鼠检测（源码同文件编辑≥10次硬停止）
│   │   └── post-error-remind.sh       # 错误后调试流程提醒
│   ├── agents/
│   │   ├── reviewer.md                # 代码审查员（独立 context）
│   │   └── investigator.md            # 代码调查员（隔离调研）
│   └── skills/
│       └── commit/SKILL.md            # /commit 智能提交
├── docs/
│   ├── progress.md                    # 进度记录（Claude 维护）
│   └── debug-log.md                   # 调试日志（Claude 维护）
└── ~/.claude/
    └── CLAUDE.md                      # 全局通用纪律（可选）
```

## 各层详解

### Rules（自动注入）

放在 `.claude/rules/` 下的 Markdown 文件会根据 `globs` 匹配自动注入到 Claude 的上下文中。
Claude 无法选择性忽略这些规则——它们在操作匹配文件时会自动出现。

**核心规则**（对所有文件生效）：
- `00-core-principles.md` — 先理解再动手、不锁定第一解释、连续3次失败必须停下
- `01-debugging.md` — 四阶段调试流程（收集→假设→验证→修复）
- `03-context-mgmt.md` — 主动检查点、调研隔离、compact 策略
- `04-no-mole-whacking.md` — 打地鼠检测和汇报模板

**源码规则**（编辑 src/ 等目录时生效）：
- `02-before-edit.md` — 修改前的 5 项强制检查

**技术栈规则**（按文件类型触发）：
- `.v/.sv/.vhd` → RTL 规则（时序意识、CDC 检查、综合/仿真区分）
- `.c/.h` → 嵌入式规则（资源意识、中断安全、volatile）
- `.py` → Python 规则（类型标注、依赖管理、测试）
- `.js/.ts/.tsx` → JS/TS 规则（类型安全、异步处理）
- `.swift/.kt/.dart` → 移动端规则（主线程、生命周期、权限）

### Hooks（代码强制）

Hooks 是在 Claude 执行操作前/后自动运行的 shell 脚本。**exit 2 可以直接阻止操作**。

| Hook | 触发时机 | 作用 |
|------|---------|------|
| `streak-breaker.sh` | 编辑文件前 | 源码同文件编辑 ≥6 次警告、**≥10 次硬停止**；配置与文档为 10 / 16。用户确认为计划内改动后，两个阈值翻倍 |
| `pre-edit-guard.sh` | 编辑文件前 | 检查 debug-log 中仍标 pending 的假设、超大 diff、新建脚本 —— **均为上下文提示，不阻断**（2026-07-30 从硬阻断降级） |
| `post-error-remind.sh` | 执行命令后 | 检测到错误输出时提醒遵守调试纪律 |

**实际效果演示：**

**streak-breaker** — 阻止打地鼠：

```
你：  "修一下 auth.py 的登录验证 bug"

Claude: 我来修正验证逻辑。
        [编辑 src/auth.py — 修正邮箱正则]

Claude: 正则不够，再加个长度检查。
        [编辑 src/auth.py — 增加输入长度验证]

Claude: 把之前的测试搞挂了，调整一下。
        [编辑 src/auth.py — 修复测试兼容性]
        ⚠️ 提示：auth.py 已被编辑 6 次。
        检查一下：这些修改是在推进目标，还是在修前面的修改？

Claude: 换个思路重写验证层。
        [编辑 src/auth.py — 重写验证逻辑]
        [… 中间还有三次编辑 …]

Claude: 差不多了，再调一下...
        [编辑 src/auth.py — 被阻止]

        🛑 编辑检查点
        文件 auth.py 本次会话已被编辑 10 次。
        反思：
          1. 这些修改是在推进目标，还是在修之前的修改？
          2. 如果是后者：停下来，寻找根本原因。

Claude: 你说得对。回顾这 10 次编辑，我一直在修症状。
        真正的问题是 User 模型的 validate() 在
        sanitization 之前被调用了。我应该从源头修。
```

没有这个 hook，Claude 会无限编辑 auth.py — 每次修复都制造下一个 bug。hook 强制暂停，引导发现根本原因。

---

**pre-edit-guard** — 在跳过诊断直接改代码时提示（2026-07-30 起为提示，不阻断）：

```
你：  "API 的 /users 接口返回 500 错误"

Claude: 我来排查。
        [执行: curl localhost:3000/users]
        → 500 Internal Server Error

Claude: 我觉得是数据库连接池的问题，改一下配置。
        [编辑 src/db.py]

        DEBUG-LOG 提示：docs/debug-log.md 中有 2 个假设
        仍标记为 pending。如果这次编辑就是其中某条的修复，
        请先更新它的状态，让日志保持真实；
        如果是无关的工作，继续即可。

Claude: 对，我还没验证我的假设。先看看错误日志。
        [执行: tail -50 logs/error.log]
        → TypeError: Cannot read property 'map' of undefined
           at UserSerializer.format (src/serializers.py:42)

Claude: 错误在序列化器，不是数据库。我的第一个
        假设是错的。先更新 debug-log.md 再修真正的问题。
```

没有这个 hook，Claude 会"修好"数据库配置 — 一个完全正常的组件 — 而真正的 bug 依然存在。

---

**post-error-remind** — 阻止看到报错就冲动改代码：

```
Claude: 跑一下测试。
        [执行: pytest tests/]
        → FAILED tests/test_auth.py::test_login - AssertionError
        → 1 failed, 23 passed

        ⚡ 检测到错误 — 调试清单：
        1. 不要立即修改代码
        2. 先完整理解错误信息
        3. 列出 ≥3 个可能原因
        4. 然后再动手

Claude: 先别急着改。测试期望 200 但拿到了 401。
        三个可能原因：
        1. Token 生成逻辑变了（检查 auth.py 的改动）
        2. 测试用的 mock token 过期了
        3. 中间件顺序在最近的重构后变了
        让我逐个验证...
```

没有这个 hook，Claude 的本能是立即打开测试文件或源文件开始编辑。提醒强制了一个诊断暂停。

**调整硬度**：编辑 hook 脚本中的 `exit` 返回值：
- `exit 0` = 允许操作（可附带提醒信息）
- `exit 1` = 报错但不阻止操作（hook 执行失败）
- `exit 2` = 阻止操作，Claude 看到消息后会调整行为（硬停止）

### Subagents（独立判断）

| Agent | 用途 | 权限 |
|-------|------|------|
| `reviewer` | 审查修改方案是否合理 | 只读（Read, Grep, Glob） |
| `investigator` | 深入调研代码库 | 只读 + Bash（仅限查询命令） |

使用方式：
```
让 reviewer 审查我的修改方案
让 investigator 调查 src/auth/ 模块的实现
```

## 自定义

### 添加项目特有规则

```bash
# Create a new rule
cat > .claude/rules/my-rule.md << 'EOF'
---
globs: "src/api/**/*"
description: "API 层特有规则"
---
## API 修改规则
- 所有 API 变更必须向后兼容
- 新增 endpoint 必须有对应的 OpenAPI spec 更新
EOF
```

### 调整 Hook 灵敏度

编辑 `.claude/hooks/streak-breaker.sh`：
```bash
WARN_THRESHOLD=6     # 同一源码文件编辑 N 次后警告
STOP_THRESHOLD=10    # 同一源码文件编辑 N 次后硬停止
# 配置与文档文件为 10/16；用户确认为计划内改动后两者翻倍
```

### 添加新的子代理

```bash
cat > .claude/agents/my-agent.md << 'EOF'
---
name: my-agent
description: "描述这个子代理做什么"
model: sonnet
tools: Read, Grep, Glob
---
你是 [角色描述]。你的职责是...
EOF
```

## FAQ

**Q: Rules 和 CLAUDE.md 有什么区别？**  
A: CLAUDE.md 在对话开始时读取一次。Rules 是按文件路径匹配自动注入的——当 Claude 操作匹配 glob 的文件时，对应规则会自动出现在它的上下文中。Rules 更可靠，因为它们不依赖 Claude "记得去看"。

**Q: Hooks 会影响性能吗？**  
A: 几乎不会。它们是轻量的 shell 脚本，执行时间通常 <100ms。

**Q: 可以把 .claude/ 提交到 git 吗？**  
A: 强烈建议提交。这样团队成员都能共享同一套纪律。注意 `.claude/settings.json` 中的 hooks 路径是相对路径，团队成员不需要额外配置。

**Q: 和 devpace 等第三方工具冲突吗？**  
A: 不冲突。本框架是纯文件级别的，不依赖任何第三方工具。可以和 devpace、Claude MPM 等工具并行使用。

## License

MIT — 自由使用、修改、分发。
