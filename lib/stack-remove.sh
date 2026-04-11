#!/bin/bash
# cc-discipline remove-stack — remove stack rules
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo "Usage: cc-discipline remove-stack <numbers>"
    echo "  e.g.: cc-discipline remove-stack 1 2"
    echo ""
    echo "Stacks: 1=RTL  2=Embedded  3=Python  4=JS/TS  5=Mobile"
    exit 1
fi

if [ ! -f ".claude/.cc-discipline-version" ]; then
    echo -e "${RED}cc-discipline is not installed in this project.${NC}"
    exit 1
fi

for choice in "$@"; do
    case $choice in
        1)
            FILE=".claude/rules/stacks/rtl.md"
            NAME="RTL"
            ;;
        2)
            FILE=".claude/rules/stacks/embedded.md"
            NAME="Embedded"
            ;;
        3)
            FILE=".claude/rules/stacks/python.md"
            NAME="Python"
            ;;
        4)
            FILE=".claude/rules/stacks/js-ts.md"
            NAME="JS/TS"
            ;;
        5)
            FILE=".claude/rules/stacks/mobile.md"
            NAME="Mobile"
            ;;
        *)
            echo -e "${YELLOW}Unknown stack: $choice (valid: 1-5)${NC}"
            continue
            ;;
    esac

    if [ -f "$FILE" ]; then
        rm "$FILE"
        echo -e "${GREEN}✓${NC} Removed $NAME stack ($FILE)"
    else
        echo -e "${YELLOW}!${NC} $NAME stack not installed, skipping"
    fi
done

echo ""
echo "Done. Remaining stacks:"
REMAINING=$(ls .claude/rules/stacks/*.md 2>/dev/null || true)
if [ -n "$REMAINING" ]; then
    for f in $REMAINING; do
        echo "  - $(basename "$f" .md)"
    done
else
    echo "  (none)"
fi
