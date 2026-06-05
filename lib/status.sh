#!/bin/bash
# cc-discipline status — show what's installed in the current project
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "cc-discipline status"
echo "──────────────────────"
echo ""

# Version
if [ -f ".claude/.cc-discipline-version" ]; then
    echo -e "Version:  ${GREEN}$(cat .claude/.cc-discipline-version)${NC}"
else
    echo -e "Version:  ${RED}not installed${NC}"
    echo ""
    echo "Run 'npx cc-discipline init' to install."
    exit 0
fi

# Stacks
echo -n "Stacks:   "
STACKS=""
[ -f ".claude/rules/stacks/rtl.md" ] && STACKS="${STACKS}RTL "
[ -f ".claude/rules/stacks/embedded.md" ] && STACKS="${STACKS}Embedded "
[ -f ".claude/rules/stacks/python.md" ] && STACKS="${STACKS}Python "
[ -f ".claude/rules/stacks/js-ts.md" ] && STACKS="${STACKS}JS/TS "
[ -f ".claude/rules/stacks/mobile.md" ] && STACKS="${STACKS}Mobile "
if [ -n "$STACKS" ]; then
    echo -e "${GREEN}${STACKS}${NC}"
else
    echo -e "${YELLOW}General (no stack rules)${NC}"
fi

# Core rules
CORE_COUNT=0
for f in .claude/rules/0*.md; do
    [ -f "$f" ] && CORE_COUNT=$((CORE_COUNT + 1))
done
echo -e "Rules:    ${GREEN}${CORE_COUNT} core rules${NC}"

# Hooks
echo -n "Hooks:    "
HOOKS=""
[ -f ".claude/hooks/pre-edit-guard.sh" ] && HOOKS="${HOOKS}pre-edit-guard "
[ -f ".claude/hooks/streak-breaker.sh" ] && HOOKS="${HOOKS}streak-breaker "
[ -f ".claude/hooks/post-error-remind.sh" ] && HOOKS="${HOOKS}post-error-remind "
[ -f ".claude/hooks/session-start.sh" ] && HOOKS="${HOOKS}session-start "
[ -f ".claude/hooks/phase-gate.sh" ] && HOOKS="${HOOKS}phase-gate "
[ -f ".claude/hooks/action-counter.sh" ] && HOOKS="${HOOKS}action-counter "
[ -f ".claude/hooks/git-guard.sh" ] && HOOKS="${HOOKS}git-guard "
HOOK_COUNT=$(echo "$HOOKS" | wc -w | tr -d ' ')
echo -e "${GREEN}${HOOK_COUNT}/7${NC} (${HOOKS% })"

# Agents
echo -n "Agents:   "
AGENTS=""
[ -f ".claude/agents/reviewer.md" ] && AGENTS="${AGENTS}reviewer "
[ -f ".claude/agents/investigator.md" ] && AGENTS="${AGENTS}investigator "
AGENT_COUNT=$(echo "$AGENTS" | wc -w | tr -d ' ')
echo -e "${GREEN}${AGENT_COUNT}/2${NC} (${AGENTS% })"

# Skills
echo -n "Skills:   "
SKILLS=""
for skill_dir in .claude/skills/*/; do
    [ -d "$skill_dir" ] || continue
    SKILLS="${SKILLS}/$(basename "$skill_dir") "
done
SKILL_COUNT=$(echo "$SKILLS" | wc -w | tr -d ' ')
echo -e "${GREEN}${SKILL_COUNT}${NC} (${SKILLS% })"

# Settings
echo -n "Settings: "
if [ -f ".claude/settings.json" ]; then
    if command -v jq &>/dev/null; then
        HOOK_EVENTS=$(jq -r '.hooks // {} | keys[]' .claude/settings.json 2>/dev/null | tr '\n' ' ')
        echo -e "${GREEN}registered${NC} (events: ${HOOK_EVENTS% })"
    else
        echo -e "${GREEN}exists${NC}"
    fi
else
    echo -e "${RED}missing${NC}"
fi

# CLAUDE.md
echo -n "CLAUDE.md: "
if [ -f "CLAUDE.md" ]; then
    echo -e "${GREEN}exists${NC}"
else
    echo -e "${YELLOW}missing${NC}"
fi

echo ""
