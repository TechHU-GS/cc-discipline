#!/bin/bash
# cc-discipline init script
# Usage: cd your-project && bash /path/to/init.sh
# Or:    curl -sL https://raw.githubusercontent.com/YOU/cc-discipline/main/init.sh | bash

set -e

# ─── Colors ───
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(pwd)"

echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Claude Code 项目纪律框架 — 初始化工具       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "项目目录: ${GREEN}${PROJECT_DIR}${NC}"
echo ""

# ─── Check if already initialized ───
if [ -d ".claude/rules" ] && [ -f "CLAUDE.md" ]; then
    echo -e "${YELLOW}⚠️  检测到已有 CLAUDE.md 和 .claude/rules/${NC}"
    read -p "是否覆盖？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "已取消。"
        exit 0
    fi
fi

# ─── Select project type ───
echo -e "${BLUE}你的项目类型是？（可多选，用空格分隔数字）${NC}"
echo "  1) RTL / IC 设计 (Verilog, VHDL, SystemVerilog)"
echo "  2) 嵌入式开发 (C/C++, bare-metal, RTOS)"
echo "  3) Python 后端 / 脚本 / ML"
echo "  4) JavaScript / TypeScript (Node, Web)"
echo "  5) 移动端 (Swift, Kotlin, React Native, Flutter)"
echo "  6) 全栈 Web (前端 + 后端)"
echo "  7) 其他 / 通用"
echo ""
read -p "选择 (例如: 1 2 或 3 4 6): " STACK_CHOICES

# Parse choices into array
IFS=' ' read -ra STACKS <<< "$STACK_CHOICES"

# ─── Project name ───
DEFAULT_NAME=$(basename "$PROJECT_DIR")
read -p "项目名称 [$DEFAULT_NAME]: " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-$DEFAULT_NAME}

# ─── Create directory structure ───
echo ""
echo -e "${GREEN}📁 创建目录结构...${NC}"
mkdir -p .claude/rules/stacks
mkdir -p .claude/hooks
mkdir -p .claude/agents
mkdir -p .claude/skills
mkdir -p docs

# ─── Copy core rules (always applied) ───
echo -e "${GREEN}📋 安装核心规则...${NC}"
cp "$SCRIPT_DIR/templates/.claude/rules/00-core-principles.md" .claude/rules/
cp "$SCRIPT_DIR/templates/.claude/rules/01-debugging.md" .claude/rules/
cp "$SCRIPT_DIR/templates/.claude/rules/02-before-edit.md" .claude/rules/
cp "$SCRIPT_DIR/templates/.claude/rules/03-context-mgmt.md" .claude/rules/
cp "$SCRIPT_DIR/templates/.claude/rules/04-no-mole-whacking.md" .claude/rules/

# ─── Copy stack-specific rules based on selection ───
echo -e "${GREEN}📋 安装技术栈规则...${NC}"
for choice in "${STACKS[@]}"; do
    case $choice in
        1)
            cp "$SCRIPT_DIR/templates/.claude/rules/stacks/rtl.md" .claude/rules/stacks/
            echo "   ✓ RTL / IC 设计规则"
            ;;
        2)
            cp "$SCRIPT_DIR/templates/.claude/rules/stacks/embedded.md" .claude/rules/stacks/
            echo "   ✓ 嵌入式开发规则"
            ;;
        3)
            cp "$SCRIPT_DIR/templates/.claude/rules/stacks/python.md" .claude/rules/stacks/
            echo "   ✓ Python 规则"
            ;;
        4)
            cp "$SCRIPT_DIR/templates/.claude/rules/stacks/js-ts.md" .claude/rules/stacks/
            echo "   ✓ JavaScript / TypeScript 规则"
            ;;
        5)
            cp "$SCRIPT_DIR/templates/.claude/rules/stacks/mobile.md" .claude/rules/stacks/
            echo "   ✓ 移动端规则"
            ;;
        6)
            cp "$SCRIPT_DIR/templates/.claude/rules/stacks/js-ts.md" .claude/rules/stacks/
            cp "$SCRIPT_DIR/templates/.claude/rules/stacks/python.md" .claude/rules/stacks/
            echo "   ✓ 全栈规则 (JS/TS + Python)"
            ;;
        7)
            echo "   ✓ 通用规则（无额外技术栈规则）"
            ;;
    esac
done

# ─── Install hooks ───
echo -e "${GREEN}🪝 安装 Hooks...${NC}"
cp "$SCRIPT_DIR/templates/.claude/hooks/pre-edit-guard.sh" .claude/hooks/
cp "$SCRIPT_DIR/templates/.claude/hooks/post-error-remind.sh" .claude/hooks/
cp "$SCRIPT_DIR/templates/.claude/hooks/streak-breaker.sh" .claude/hooks/
chmod +x .claude/hooks/*.sh

# ─── Check jq availability ───
if ! command -v jq &>/dev/null; then
    echo ""
    echo -e "${YELLOW}⚠️  未检测到 jq — Hooks 会使用 grep/sed 回退解析，但推荐安装 jq 以获得更可靠的 JSON 解析${NC}"
    echo "  macOS:   brew install jq"
    echo "  Ubuntu:  sudo apt install jq"
    echo "  Arch:    sudo pacman -S jq"
    echo ""
fi

# ─── Install settings.json ───
cp "$SCRIPT_DIR/templates/.claude/settings.json" .claude/settings.json

# ─── Install subagents ───
echo -e "${GREEN}🤖 安装子代理...${NC}"
cp "$SCRIPT_DIR/templates/.claude/agents/reviewer.md" .claude/agents/
cp "$SCRIPT_DIR/templates/.claude/agents/investigator.md" .claude/agents/

# ─── Install skills ───
echo -e "${GREEN}⚡ 安装 Skills...${NC}"
cp -r "$SCRIPT_DIR/templates/.claude/skills/commit" .claude/skills/
echo "   ✓ /commit — 智能提交（测试 → 更新记忆 → 提交）"

# ─── Generate CLAUDE.md ───
echo -e "${GREEN}📝 生成 CLAUDE.md...${NC}"
sed "s/\[PROJECT_NAME\]/$PROJECT_NAME/g" "$SCRIPT_DIR/templates/CLAUDE.md" > CLAUDE.md

# ─── Copy docs templates ───
if [ ! -f "docs/progress.md" ]; then
    cp "$SCRIPT_DIR/templates/docs/progress.md" docs/
fi
if [ ! -f "docs/debug-log.md" ]; then
    cp "$SCRIPT_DIR/templates/docs/debug-log.md" docs/
fi

# ─── Install auto memory ───
echo -e "${GREEN}🧠 安装 Auto Memory...${NC}"
# Claude Code auto memory 路径：~/.claude/projects/-<项目绝对路径用-连接>/memory/
MEMORY_PROJECT_KEY=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
MEMORY_DIR="$HOME/.claude/projects/${MEMORY_PROJECT_KEY}/memory"
mkdir -p "$MEMORY_DIR"
if [ ! -f "$MEMORY_DIR/MEMORY.md" ]; then
    cp "$SCRIPT_DIR/templates/memory/MEMORY.md" "$MEMORY_DIR/MEMORY.md"
    echo "   ✓ Memory 已安装到 $MEMORY_DIR/MEMORY.md"
else
    echo -e "   ${YELLOW}已有 MEMORY.md，跳过（不覆盖）${NC}"
fi

# ─── Install global rules (optional) ───
echo ""
echo -e "${BLUE}是否同时安装全局规则到 ~/.claude/CLAUDE.md ？${NC}"
echo "  （全局规则对所有项目生效，只需安装一次）"
read -p "安装全局规则？(y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p ~/.claude
    if [ -f ~/.claude/CLAUDE.md ]; then
        echo -e "${YELLOW}  已有 ~/.claude/CLAUDE.md，备份为 ~/.claude/CLAUDE.md.bak${NC}"
        cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak
    fi
    cp "$SCRIPT_DIR/global/CLAUDE.md" ~/.claude/CLAUDE.md
    echo -e "${GREEN}  ✓ 全局规则已安装${NC}"
fi

# ─── Summary ───
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  ✅ 初始化完成!                              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "已创建文件:"
echo -e "  ${GREEN}CLAUDE.md${NC}                    ← 项目规则（请填写 [待填写] 部分）"
echo -e "  ${GREEN}.claude/rules/${NC}               ← 自动注入规则"
echo -e "  ${GREEN}.claude/hooks/${NC}               ← 强制执行钩子"
echo -e "  ${GREEN}.claude/agents/${NC}              ← 审查员 & 调查员子代理"
echo -e "  ${GREEN}.claude/skills/commit/${NC}       ← /commit 智能提交"
echo -e "  ${GREEN}.claude/settings.json${NC}        ← Hooks 配置"
echo -e "  ${GREEN}docs/progress.md${NC}             ← 进度记录（Claude 维护）"
echo -e "  ${GREEN}docs/debug-log.md${NC}            ← 调试日志（Claude 维护）"
echo -e "  ${GREEN}~/.claude/projects/.../memory/${NC} ← Auto Memory（跨会话记忆）"
echo ""
echo -e "${YELLOW}下一步:${NC}"
echo "  1. 编辑 CLAUDE.md，填写 [待填写] 的项目信息"
echo "  2. 检查 .claude/rules/stacks/ 下的规则，按需调整"
echo "  3. 开始用 Claude Code 工作！"
echo ""
echo -e "${YELLOW}提示:${NC} 将 .claude/ 和 CLAUDE.md 提交到 git，团队共享纪律"
