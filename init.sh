#!/bin/bash
# cc-discipline init script
# Usage: cd your-project && bash /path/to/init.sh
# Or:    curl -sL https://raw.githubusercontent.com/YOU/cc-discipline/main/init.sh | bash

set -e

# ─── Version ───
VERSION="2.0.0"

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
echo -e "${CYAN}║  Claude Code Discipline Framework — Setup     ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Project directory: ${GREEN}${PROJECT_DIR}${NC}"

# ─── Detect install mode ───
INSTALL_MODE="fresh"
INSTALLED_VERSION=""

if [ -f ".claude/.cc-discipline-version" ]; then
    INSTALL_MODE="upgrade"
    INSTALLED_VERSION=$(cat ".claude/.cc-discipline-version")
elif [ -f ".claude/hooks/streak-breaker.sh" ] || [ -f ".claude/hooks/pre-edit-guard.sh" ]; then
    INSTALL_MODE="upgrade"
    INSTALLED_VERSION="<2.0.0"
elif [ -d ".claude" ] || [ -f "CLAUDE.md" ]; then
    INSTALL_MODE="append"
fi

case "$INSTALL_MODE" in
    fresh)
        echo -e "Mode: ${GREEN}Fresh install${NC}"
        ;;
    upgrade)
        echo -e "Mode: ${YELLOW}Upgrade cc-discipline (${INSTALLED_VERSION} → ${VERSION})${NC}"
        ;;
    append)
        echo -e "Mode: ${YELLOW}Adding discipline to existing project${NC}"
        echo -e "${YELLOW}Your existing files will be preserved. cc-discipline files will be added alongside them.${NC}"
        ;;
esac
echo ""

# ─── Backup (upgrade/append) ───
BACKUP_DIR=""
if [ "$INSTALL_MODE" != "fresh" ]; then
    BACKUP_DIR=".claude/.backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    [ -f "CLAUDE.md" ] && cp "CLAUDE.md" "$BACKUP_DIR/"
    [ -f ".claude/settings.json" ] && cp ".claude/settings.json" "$BACKUP_DIR/"
    [ -d ".claude/hooks" ] && cp -r ".claude/hooks" "$BACKUP_DIR/"
    [ -d ".claude/rules" ] && cp -r ".claude/rules" "$BACKUP_DIR/"
    [ -d ".claude/agents" ] && cp -r ".claude/agents" "$BACKUP_DIR/"
    [ -d ".claude/skills" ] && cp -r ".claude/skills" "$BACKUP_DIR/"
    echo -e "${GREEN}Backup saved to ${BACKUP_DIR}/${NC}"
    echo ""
fi

# ─── Detect installed stacks (for upgrade/append) ───
detect_installed_stacks() {
    INSTALLED_STACKS=""
    [ -f ".claude/rules/stacks/rtl.md" ] && INSTALLED_STACKS="${INSTALLED_STACKS}1 "
    [ -f ".claude/rules/stacks/embedded.md" ] && INSTALLED_STACKS="${INSTALLED_STACKS}2 "
    [ -f ".claude/rules/stacks/python.md" ] && INSTALLED_STACKS="${INSTALLED_STACKS}3 "
    [ -f ".claude/rules/stacks/js-ts.md" ] && INSTALLED_STACKS="${INSTALLED_STACKS}4 "
    [ -f ".claude/rules/stacks/mobile.md" ] && INSTALLED_STACKS="${INSTALLED_STACKS}5 "
    return 0
}

# ─── Select project type ───
if [ "$INSTALL_MODE" = "fresh" ]; then
    echo -e "${BLUE}What is your project type? (select multiple with spaces)${NC}"
    echo "  1) RTL / IC Design (Verilog, VHDL, SystemVerilog)"
    echo "  2) Embedded (C/C++, bare-metal, RTOS)"
    echo "  3) Python (backend / scripting / ML)"
    echo "  4) JavaScript / TypeScript (Node, Web)"
    echo "  5) Mobile (Swift, Kotlin, React Native, Flutter)"
    echo "  6) Full-stack Web (frontend + backend)"
    echo "  7) Other / General"
    echo ""
    read -p "Choose (e.g.: 1 2 or 3 4 6): " STACK_CHOICES
else
    detect_installed_stacks
    echo -e "${BLUE}Stack rules (* = already installed):${NC}"
    for i in 1 2 3 4 5; do
        MARKER=""
        echo "$INSTALLED_STACKS" | grep -q "$i" && MARKER=" ${GREEN}*${NC}"
        case $i in
            1) echo -e "  1) RTL / IC Design${MARKER}" ;;
            2) echo -e "  2) Embedded${MARKER}" ;;
            3) echo -e "  3) Python${MARKER}" ;;
            4) echo -e "  4) JavaScript / TypeScript${MARKER}" ;;
            5) echo -e "  5) Mobile${MARKER}" ;;
        esac
    done
    echo "  6) Full-stack Web (JS/TS + Python)"
    echo "  7) Other / General"
    echo ""
    read -p "Add stacks (e.g.: 2 4), or press Enter to keep current: " STACK_CHOICES
fi

# Parse choices into array
IFS=' ' read -ra STACKS <<< "$STACK_CHOICES"

# ─── Project name ───
if [ "$INSTALL_MODE" = "fresh" ]; then
    DEFAULT_NAME=$(basename "$PROJECT_DIR")
    read -p "Project name [$DEFAULT_NAME]: " PROJECT_NAME
    PROJECT_NAME=${PROJECT_NAME:-$DEFAULT_NAME}
else
    # Try to extract from existing CLAUDE.md: "# MyProject — CLAUDE.md"
    PROJECT_NAME=""
    if [ -f "CLAUDE.md" ]; then
        PROJECT_NAME=$(head -1 CLAUDE.md | sed 's/^# //;s/ — CLAUDE.md$//' 2>/dev/null)
    fi
    if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "[PROJECT_NAME]" ]; then
        DEFAULT_NAME=$(basename "$PROJECT_DIR")
        read -p "Project name [$DEFAULT_NAME]: " PROJECT_NAME
        PROJECT_NAME=${PROJECT_NAME:-$DEFAULT_NAME}
    else
        echo -e "Project name: ${GREEN}${PROJECT_NAME}${NC} (from CLAUDE.md)"
    fi
fi

# ─── Create directory structure ───
echo ""
echo -e "${GREEN}Creating directory structure...${NC}"
mkdir -p .claude/rules/stacks
mkdir -p .claude/hooks
mkdir -p .claude/agents
mkdir -p .claude/skills
mkdir -p docs

# ─── Copy core rules (always applied, always overwrite — these are framework files) ───
echo -e "${GREEN}Installing core rules...${NC}"
cp "$SCRIPT_DIR/templates/.claude/rules/00-core-principles.md" .claude/rules/
cp "$SCRIPT_DIR/templates/.claude/rules/01-debugging.md" .claude/rules/
cp "$SCRIPT_DIR/templates/.claude/rules/02-before-edit.md" .claude/rules/
cp "$SCRIPT_DIR/templates/.claude/rules/03-context-mgmt.md" .claude/rules/
cp "$SCRIPT_DIR/templates/.claude/rules/04-no-mole-whacking.md" .claude/rules/
cp "$SCRIPT_DIR/templates/.claude/rules/05-phase-discipline.md" .claude/rules/
cp "$SCRIPT_DIR/templates/.claude/rules/06-multi-task.md" .claude/rules/

# ─── Copy stack-specific rules based on selection ───
if [ ${#STACKS[@]} -gt 0 ] && [ -n "${STACKS[0]}" ]; then
    echo -e "${GREEN}Installing stack rules...${NC}"
    for choice in "${STACKS[@]}"; do
        case $choice in
            1)
                cp "$SCRIPT_DIR/templates/.claude/rules/stacks/rtl.md" .claude/rules/stacks/
                echo "   ✓ RTL / IC Design rules"
                ;;
            2)
                cp "$SCRIPT_DIR/templates/.claude/rules/stacks/embedded.md" .claude/rules/stacks/
                echo "   ✓ Embedded development rules"
                ;;
            3)
                cp "$SCRIPT_DIR/templates/.claude/rules/stacks/python.md" .claude/rules/stacks/
                echo "   ✓ Python rules"
                ;;
            4)
                cp "$SCRIPT_DIR/templates/.claude/rules/stacks/js-ts.md" .claude/rules/stacks/
                echo "   ✓ JavaScript / TypeScript rules"
                ;;
            5)
                cp "$SCRIPT_DIR/templates/.claude/rules/stacks/mobile.md" .claude/rules/stacks/
                echo "   ✓ Mobile development rules"
                ;;
            6)
                cp "$SCRIPT_DIR/templates/.claude/rules/stacks/js-ts.md" .claude/rules/stacks/
                cp "$SCRIPT_DIR/templates/.claude/rules/stacks/python.md" .claude/rules/stacks/
                echo "   ✓ Full-stack rules (JS/TS + Python)"
                ;;
            7)
                echo "   ✓ General rules (no additional stack rules)"
                ;;
        esac
    done
fi

# ─── Install hooks ───
echo -e "${GREEN}Installing hooks...${NC}"
cp "$SCRIPT_DIR/templates/.claude/hooks/pre-edit-guard.sh" .claude/hooks/
cp "$SCRIPT_DIR/templates/.claude/hooks/post-error-remind.sh" .claude/hooks/
cp "$SCRIPT_DIR/templates/.claude/hooks/streak-breaker.sh" .claude/hooks/
chmod +x .claude/hooks/*.sh

# ─── Check jq availability ───
HAS_JQ=false
if command -v jq &>/dev/null; then
    HAS_JQ=true
else
    echo ""
    echo -e "${YELLOW}Warning: jq not found — Hooks will use grep/sed fallback, but jq is recommended${NC}"
    echo "  macOS:   brew install jq"
    echo "  Ubuntu:  sudo apt install jq"
    echo "  Arch:    sudo pacman -S jq"
    echo ""
fi

# ─── Install/merge settings.json ───
SETTINGS_TEMPLATE="$SCRIPT_DIR/templates/.claude/settings.json"

if [ ! -f ".claude/settings.json" ]; then
    # No existing settings.json — just copy template
    cp "$SETTINGS_TEMPLATE" .claude/settings.json
    echo -e "${GREEN}   ✓ settings.json created${NC}"
elif [ "$INSTALL_MODE" = "fresh" ]; then
    # Fresh mode shouldn't reach here, but just in case
    cp "$SETTINGS_TEMPLATE" .claude/settings.json
else
    # Merge: preserve user hooks, add/update cc-discipline hooks
    if [ "$HAS_JQ" = true ]; then
        TEMP_SETTINGS=$(mktemp)
        MERGE_OK=false

        if jq -s '
          .[0] as $e | .[1] as $t |
          def is_cc: .hooks | any(.command | test("pre-edit-guard|streak-breaker|post-error-remind"));
          def merge($ev): (($e.hooks[$ev] // []) | map(select(is_cc | not))) + ($t.hooks[$ev] // []);
          $e * {
            hooks: (($e.hooks // {}) + {
              PreToolUse: merge("PreToolUse"),
              PostToolUse: merge("PostToolUse"),
              PostToolUseFailure: merge("PostToolUseFailure")
            } | with_entries(select(.value | length > 0)))
          }
        ' .claude/settings.json "$SETTINGS_TEMPLATE" > "$TEMP_SETTINGS" 2>/dev/null; then
            # Verify the output is valid JSON
            if jq empty "$TEMP_SETTINGS" 2>/dev/null; then
                mv "$TEMP_SETTINGS" .claude/settings.json
                MERGE_OK=true
                echo -e "${GREEN}   ✓ settings.json merged (your existing hooks preserved)${NC}"
            fi
        fi

        if [ "$MERGE_OK" = false ]; then
            rm -f "$TEMP_SETTINGS"
            echo -e "${YELLOW}   Warning: settings.json merge failed. Your file was NOT modified.${NC}"
            echo -e "${YELLOW}   Backed up to: ${BACKUP_DIR}/settings.json${NC}"
            cp "$SETTINGS_TEMPLATE" .claude/.cc-discipline-settings-template.json
            echo -e "${YELLOW}   See .claude/.cc-discipline-settings-template.json for hooks to add manually.${NC}"
        fi
    else
        # No jq — don't touch existing settings.json
        echo -e "${YELLOW}   settings.json: cannot merge without jq. Your file was NOT modified.${NC}"
        echo -e "${YELLOW}   Backed up to: ${BACKUP_DIR}/settings.json${NC}"
        cp "$SETTINGS_TEMPLATE" .claude/.cc-discipline-settings-template.json
        echo -e "${YELLOW}   See .claude/.cc-discipline-settings-template.json for hooks to add manually.${NC}"
    fi
fi

# ─── Install subagents ───
echo -e "${GREEN}Installing subagents...${NC}"
cp "$SCRIPT_DIR/templates/.claude/agents/reviewer.md" .claude/agents/
cp "$SCRIPT_DIR/templates/.claude/agents/investigator.md" .claude/agents/

# ─── Install skills ───
echo -e "${GREEN}Installing skills...${NC}"
cp -r "$SCRIPT_DIR/templates/.claude/skills/commit" .claude/skills/
echo "   ✓ /commit — smart commit (test → update memory → commit)"

# ─── Handle CLAUDE.md ───
if [ ! -f "CLAUDE.md" ]; then
    # No CLAUDE.md exists — generate from template
    echo -e "${GREEN}Generating CLAUDE.md...${NC}"
    sed "s/\[PROJECT_NAME\]/$PROJECT_NAME/g" "$SCRIPT_DIR/templates/CLAUDE.md" > CLAUDE.md
else
    if [ "$INSTALL_MODE" = "fresh" ]; then
        # Should not happen (fresh mode means no existing files), but handle gracefully
        sed "s/\[PROJECT_NAME\]/$PROJECT_NAME/g" "$SCRIPT_DIR/templates/CLAUDE.md" > CLAUDE.md
    else
        # Existing CLAUDE.md — NEVER overwrite
        echo -e "${YELLOW}   CLAUDE.md already exists — NOT modified (your content is safe)${NC}"
        sed "s/\[PROJECT_NAME\]/$PROJECT_NAME/g" "$SCRIPT_DIR/templates/CLAUDE.md" \
            > .claude/.cc-discipline-claude-md-template
        echo "   Discipline template saved to .claude/.cc-discipline-claude-md-template"
        echo "   You can reference it to add discipline sections to your CLAUDE.md."
    fi
fi

# ─── Copy docs templates (only if not exist) ───
if [ ! -f "docs/progress.md" ]; then
    cp "$SCRIPT_DIR/templates/docs/progress.md" docs/
fi
if [ ! -f "docs/debug-log.md" ]; then
    cp "$SCRIPT_DIR/templates/docs/debug-log.md" docs/
fi

# ─── Install auto memory ───
echo -e "${GREEN}Installing auto memory...${NC}"
MEMORY_PROJECT_KEY=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
MEMORY_DIR="$HOME/.claude/projects/${MEMORY_PROJECT_KEY}/memory"
mkdir -p "$MEMORY_DIR"
if [ ! -f "$MEMORY_DIR/MEMORY.md" ]; then
    cp "$SCRIPT_DIR/templates/memory/MEMORY.md" "$MEMORY_DIR/MEMORY.md"
    echo "   ✓ Memory installed to $MEMORY_DIR/MEMORY.md"
else
    echo -e "   ${YELLOW}MEMORY.md already exists, skipping (no overwrite)${NC}"
fi

# ─── Install global rules (optional) ───
echo ""
echo -e "${BLUE}Install global rules to ~/.claude/CLAUDE.md?${NC}"
echo "  (Global rules apply to all projects, only needs to be installed once)"
read -p "Install global rules? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p ~/.claude
    if [ -f ~/.claude/CLAUDE.md ]; then
        echo -e "${YELLOW}  Existing ~/.claude/CLAUDE.md found, backing up to ~/.claude/CLAUDE.md.bak${NC}"
        cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak
    fi
    cp "$SCRIPT_DIR/global/CLAUDE.md" ~/.claude/CLAUDE.md
    echo -e "${GREEN}  ✓ Global rules installed${NC}"
fi

# ─── Write version marker ───
echo "$VERSION" > .claude/.cc-discipline-version

# ─── Summary ───
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Setup complete!                              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

if [ "$INSTALL_MODE" = "fresh" ]; then
    echo -e "Created files:"
    echo -e "  ${GREEN}CLAUDE.md${NC}                    ← Project rules (fill in [TODO] sections)"
    echo -e "  ${GREEN}.claude/rules/${NC}               ← Auto-injected rules"
    echo -e "  ${GREEN}.claude/hooks/${NC}               ← Enforced hooks"
    echo -e "  ${GREEN}.claude/agents/${NC}              ← Reviewer & investigator subagents"
    echo -e "  ${GREEN}.claude/skills/commit/${NC}       ← /commit smart commit"
    echo -e "  ${GREEN}.claude/settings.json${NC}        ← Hooks configuration"
    echo -e "  ${GREEN}docs/progress.md${NC}             ← Progress log (maintained by Claude)"
    echo -e "  ${GREEN}docs/debug-log.md${NC}            ← Debug log (maintained by Claude)"
    echo -e "  ${GREEN}~/.claude/projects/.../memory/${NC} ← Auto memory (cross-session)"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Edit CLAUDE.md and fill in the [TODO] sections with project info"
    echo "  2. Review rules in .claude/rules/stacks/ and adjust as needed"
    echo "  3. Start working with Claude Code!"
else
    echo -e "What was done:"
    echo -e "  ${GREEN}.claude/rules/${NC}               ← Discipline rules installed/updated"
    echo -e "  ${GREEN}.claude/hooks/${NC}               ← Hook scripts installed/updated"
    echo -e "  ${GREEN}.claude/agents/${NC}              ← Subagents installed/updated"
    echo -e "  ${GREEN}.claude/skills/commit/${NC}       ← /commit skill installed/updated"
    if [ ! -f "$BACKUP_DIR/settings.json" ] || [ -f ".claude/.cc-discipline-settings-template.json" ]; then
        echo -e "  ${YELLOW}.claude/settings.json${NC}        ← See notes above"
    else
        echo -e "  ${GREEN}.claude/settings.json${NC}        ← Hooks merged"
    fi
    echo ""
    echo -e "What was ${GREEN}NOT${NC} touched:"
    echo -e "  CLAUDE.md                    ← Your project info is safe"
    echo -e "  docs/progress.md             ← Your progress records are safe"
    echo -e "  docs/debug-log.md            ← Your debug logs are safe"
    echo -e "  Your custom rules/agents     ← Untouched (we only add our files)"
    echo ""
    echo -e "${YELLOW}Backup:${NC} ${BACKUP_DIR}/"
    echo "  Consider adding .claude/.backup-* to .gitignore"
    echo ""
    if [ -f ".claude/.cc-discipline-claude-md-template" ]; then
        echo -e "${YELLOW}Next steps:${NC}"
        echo "  1. Review .claude/.cc-discipline-claude-md-template"
        echo "     Consider adding the docs/ structure and discipline sections to your CLAUDE.md"
        echo "  2. Review rules in .claude/rules/stacks/ and adjust as needed"
        echo "  3. Start working with Claude Code!"
    else
        echo -e "${YELLOW}Next steps:${NC}"
        echo "  1. Review rules in .claude/rules/stacks/ and adjust as needed"
        echo "  2. Start working with Claude Code!"
    fi
fi
echo ""
echo -e "${YELLOW}Tip:${NC} Commit .claude/ and CLAUDE.md to git to share discipline across the team"
