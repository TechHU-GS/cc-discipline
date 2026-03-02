# cc-discipline

**Discipline framework for Claude Code** — Keep your AI coding assistant focused and disciplined during complex tasks.

[中文文档](README.zh-CN.md)

Solves common problems when using Claude Code in long conversations and complex tasks:
- Losing focus and drifting from the main objective
- Whack-a-mole symptom patching
- Locking onto the first explanation too quickly
- Losing critical context and principles after compact
- Repeating the same mistakes

## Architecture: Three Lines of Defense

```
┌─────────────────────────────────────────┐
│  Layer 3: Subagents (independent judgment) │
│  reviewer — audits plans in independent context │
│  investigator — isolated research, clean context │
├─────────────────────────────────────────┤
│  Layer 2: Hooks (code-enforced)           │
│  pre-edit-guard — pre-edit discipline check │
│  streak-breaker — detects mole-whacking   │
│  post-error-remind — post-error reminders │
├─────────────────────────────────────────┤
│  Layer 1: Rules (auto-injected)           │
│  core-principles — core principles        │
│  debugging — debugging discipline         │
│  before-edit — pre-edit checklist         │
│  context-mgmt — context management        │
│  no-mole-whacking — anti-mole-whacking    │
│  phase-discipline — phase awareness       │
│  multi-task — multi-task gate control     │
│  stacks/* — tech stack specific rules     │
├─────────────────────────────────────────┤
│  Foundation: CLAUDE.md + docs/            │
│  Project info + progress log + debug log  │
└─────────────────────────────────────────┘
```

**Rules** = posted in front of its eyes (auto-injected, triggered by file path)
**Hooks** = lock its hands (code-level enforcement, can block operations)
**Subagents** = someone watching over it (independent context review, not influenced by main conversation momentum)

## Quick Start

### Method 1: Clone + Init Script

```bash
git clone https://github.com/YOUR_USERNAME/cc-discipline.git ~/.cc-discipline

# In your project directory:
cd your-project
bash ~/.cc-discipline/init.sh
```

### Method 2: GitHub Template

1. Click the **Use this template** button on this repo
2. After creating the new project, edit `CLAUDE.md` to fill in project info

### Method 3: Global Rules Only

```bash
git clone https://github.com/YOUR_USERNAME/cc-discipline.git /tmp/cc-discipline
cp /tmp/cc-discipline/global/CLAUDE.md ~/.claude/CLAUDE.md
```

## File Structure

```
your-project/
├── CLAUDE.md                          # Project-specific info (you maintain)
├── .claude/
│   ├── settings.json                  # Hooks configuration
│   ├── rules/
│   │   ├── 00-core-principles.md      # Core working principles
│   │   ├── 01-debugging.md            # Debugging discipline
│   │   ├── 02-before-edit.md          # Pre-edit checklist
│   │   ├── 03-context-mgmt.md         # Context management
│   │   ├── 04-no-mole-whacking.md     # Anti-mole-whacking
│   │   ├── 05-phase-discipline.md     # Phase awareness
│   │   ├── 06-multi-task.md           # Multi-task gate control
│   │   └── stacks/                    # Tech stack specific rules
│   │       ├── rtl.md                 #   RTL / IC design
│   │       ├── embedded.md            #   Embedded C/C++
│   │       ├── python.md              #   Python
│   │       ├── js-ts.md               #   JavaScript/TypeScript
│   │       └── mobile.md              #   Mobile
│   ├── hooks/
│   │   ├── pre-edit-guard.sh          # Pre-edit discipline check
│   │   ├── streak-breaker.sh          # Mole-whacking detection (hard stop at >=5 edits)
│   │   └── post-error-remind.sh       # Post-error debugging reminder
│   ├── agents/
│   │   ├── reviewer.md                # Code reviewer (independent context)
│   │   └── investigator.md            # Code investigator (isolated research)
│   └── skills/
│       └── commit/SKILL.md            # /commit smart commit
├── docs/
│   ├── progress.md                    # Progress log (maintained by Claude)
│   └── debug-log.md                   # Debug log (maintained by Claude)
└── ~/.claude/
    └── CLAUDE.md                      # Global discipline (optional)
```

## Layer Details

### Rules (auto-injected)

Markdown files in `.claude/rules/` are auto-injected into Claude's context based on `globs` matching.
Claude cannot selectively ignore these rules — they appear automatically when operating on matched files.

**Core rules** (apply to all files):
- `00-core-principles.md` — Understand before acting, don't lock onto first explanation, forced stop after 3 failures
- `01-debugging.md` — Four-phase debugging process (gather → hypothesize → verify → fix)
- `03-context-mgmt.md` — Proactive checkpoints, research isolation, compact strategy
- `04-no-mole-whacking.md` — Mole-whacking detection and report template
- `05-phase-discipline.md` — Phase awareness (research/plan/implement)
- `06-multi-task.md` — Numbered tasks, sequential completion, confirmation gates

**Source code rules** (triggered when editing src/ etc.):
- `02-before-edit.md` — 5 mandatory pre-edit checks

**Tech stack rules** (triggered by file type):
- `.v/.sv/.vhd` → RTL rules (timing awareness, CDC checks, synthesis/simulation distinction)
- `.c/.h` → Embedded rules (resource awareness, interrupt safety, volatile)
- `.py` → Python rules (type annotations, dependency management, testing)
- `.js/.ts/.tsx` → JS/TS rules (type safety, async handling)
- `.swift/.kt/.dart` → Mobile rules (main thread, lifecycle, permissions)

### Hooks (code-enforced)

Hooks are shell scripts that run automatically before/after Claude's operations. **exit 2 directly blocks the operation**.

| Hook | Trigger | Purpose |
|------|---------|---------|
| `pre-edit-guard.sh` | Before file edit | Checks for incomplete debugging process |
| `streak-breaker.sh` | Before file edit | Warns at >=3 edits, hard stop at >=5 |
| `post-error-remind.sh` | After command execution | Reminds debugging discipline when errors detected |

**Adjusting strictness**: edit the `exit` return values in hook scripts:
- `exit 0` = allow operation (can attach reminder message)
- `exit 1` = error but don't block operation (hook execution failure)
- `exit 2` = block operation, Claude sees the message and adjusts behavior (hard stop)

### Subagents (independent judgment)

| Agent | Purpose | Permissions |
|-------|---------|-------------|
| `reviewer` | Reviews modification plans for soundness | Read-only (Read, Grep, Glob) |
| `investigator` | Deep codebase research | Read-only + Bash (query commands only) |

Usage:
```
Have reviewer audit my modification plan
Have investigator research the src/auth/ module implementation
```

## Customization

### Adding project-specific rules

```bash
# Create a new rule
cat > .claude/rules/my-rule.md << 'EOF'
---
globs: "src/api/**/*"
description: "API layer specific rules"
---
## API Modification Rules
- All API changes must be backwards-compatible
- New endpoints must have corresponding OpenAPI spec updates
EOF
```

### Adjusting hook sensitivity

Edit `.claude/hooks/streak-breaker.sh`:
```bash
WARN_THRESHOLD=3    # Warning after N edits to same file
STOP_THRESHOLD=5    # Hard block after N edits to same file
```

### Adding new subagents

```bash
cat > .claude/agents/my-agent.md << 'EOF'
---
name: my-agent
description: "Describe what this subagent does"
model: sonnet
tools: Read, Grep, Glob
---
You are [role description]. Your job is...
EOF
```

## FAQ

**Q: What's the difference between Rules and CLAUDE.md?**
A: CLAUDE.md is read once at conversation start. Rules are auto-injected by file path matching — when Claude operates on files matching a glob, the corresponding rules automatically appear in its context. Rules are more reliable because they don't depend on Claude "remembering to check".

**Q: Do Hooks affect performance?**
A: Barely. They're lightweight shell scripts, typically executing in <100ms.

**Q: Should I commit .claude/ to git?**
A: Strongly recommended. This way team members share the same discipline. Note that hook paths in `.claude/settings.json` use `$CLAUDE_PROJECT_DIR`, so team members don't need extra configuration.

**Q: Does this conflict with third-party tools like devpace?**
A: No. This framework is purely file-based and doesn't depend on any third-party tools. It can work alongside devpace, Claude MPM, and other tools.

## License

MIT — free to use, modify, and distribute.
