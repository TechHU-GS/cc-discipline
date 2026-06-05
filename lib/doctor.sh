#!/bin/bash
# cc-discipline doctor — diagnose installation issues
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ISSUES=0
WARNINGS=0

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ISSUES=$((ISSUES + 1)); }

echo "cc-discipline doctor"
echo "──────────────────────"
echo ""

# 1. Version file
echo "Installation:"
if [ -f ".claude/.cc-discipline-version" ]; then
    ok "Version file: $(cat .claude/.cc-discipline-version)"
else
    fail "Not installed (no .claude/.cc-discipline-version)"
    echo ""
    echo "Run 'npx cc-discipline init' to install."
    exit 1
fi

# 2. Core rules
echo ""
echo "Core rules:"
for i in 00 01 02 03 04 05 06 07; do
    FILE=$(ls .claude/rules/${i}-*.md 2>/dev/null | head -1)
    if [ -n "$FILE" ]; then
        ok "$(basename "$FILE")"
    else
        fail "Missing rule ${i}-*.md"
    fi
done

# 3. Hooks
echo ""
echo "Hooks:"
for hook in pre-edit-guard streak-breaker post-error-remind session-start phase-gate action-counter git-guard; do
    if [ -f ".claude/hooks/${hook}.sh" ]; then
        if [ -x ".claude/hooks/${hook}.sh" ]; then
            ok "${hook}.sh"
        else
            warn "${hook}.sh exists but not executable"
        fi
    else
        fail "Missing ${hook}.sh"
    fi
done

# 4. settings.json hook registration
echo ""
echo "Hook registration:"
if [ -f ".claude/settings.json" ]; then
    if command -v jq &>/dev/null; then
        CONTENT=$(cat .claude/settings.json)
        for hook in pre-edit-guard streak-breaker post-error-remind session-start phase-gate action-counter git-guard; do
            if echo "$CONTENT" | grep -q "$hook"; then
                ok "${hook} registered"
            else
                fail "${hook} NOT registered in settings.json"
            fi
        done
    else
        warn "jq not installed — cannot verify hook registration details"
        if grep -q "pre-edit-guard" .claude/settings.json 2>/dev/null; then
            ok "settings.json contains hook references"
        else
            fail "settings.json doesn't reference any hooks"
        fi
    fi
else
    fail "settings.json missing"
fi

# 5. Agents
echo ""
echo "Agents:"
for agent in reviewer investigator; do
    if [ -f ".claude/agents/${agent}.md" ]; then
        ok "${agent}.md"
    else
        warn "Missing ${agent}.md (optional)"
    fi
done

# 6. Skills
echo ""
echo "Skills:"
SKILL_FOUND=0
for skill_dir in .claude/skills/*/; do
    [ -d "$skill_dir" ] || continue
    ok "/$(basename "$skill_dir")"
    SKILL_FOUND=$((SKILL_FOUND + 1))
done
[ "$SKILL_FOUND" -eq 0 ] && warn "No skills installed (optional)"

# 7. jq
echo ""
echo "Dependencies:"
if command -v jq &>/dev/null; then
    ok "jq installed ($(jq --version 2>&1))"
else
    warn "jq not installed — hooks use grep/sed fallback, recommend: brew install jq"
fi

# 8. CLAUDE.md
echo ""
echo "Project files:"
if [ -f "CLAUDE.md" ]; then
    if grep -q "\[TODO\]" CLAUDE.md 2>/dev/null; then
        warn "CLAUDE.md has unfilled [TODO] sections"
    else
        ok "CLAUDE.md"
    fi
else
    warn "No CLAUDE.md found"
fi

if [ -f "docs/progress.md" ]; then
    ok "docs/progress.md"
else
    warn "No docs/progress.md"
fi

# Summary
echo ""
echo "──────────────────────"
if [ "$ISSUES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
elif [ "$ISSUES" -eq 0 ]; then
    echo -e "${YELLOW}${WARNINGS} warning(s), no critical issues${NC}"
else
    echo -e "${RED}${ISSUES} issue(s), ${WARNINGS} warning(s)${NC}"
    echo "Run 'npx cc-discipline upgrade' to fix missing files."
fi
echo ""
