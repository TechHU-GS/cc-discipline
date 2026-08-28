#!/bin/bash
# cc-discipline init script
# Usage: cd your-project && bash /path/to/init.sh
#        cd your-project && bash /path/to/init.sh --auto                    # non-interactive, defaults
#        cd your-project && bash /path/to/init.sh --stack "3 4" --name myapp --global
# Or:    curl -sL https://raw.githubusercontent.com/YOU/cc-discipline/main/init.sh | bash

# On Windows (Git Bash), set -e causes silent failures due to path/command differences.
# Use explicit error checking for critical operations instead.
if [[ "$(uname -s)" != MINGW* ]] && [[ "$(uname -s)" != MSYS* ]]; then
    set -e
fi

# ─── Version ───
# cli.js sets CC_DISCIPLINE_VERSION on Windows where node paths are tricky
VERSION="${CC_DISCIPLINE_VERSION:-unknown}"
if [ "$VERSION" = "unknown" ]; then
    _INIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if command -v node &>/dev/null && [ -f "$_INIT_DIR/package.json" ]; then
        VERSION=$(node -p "require('$_INIT_DIR/package.json').version" 2>/dev/null) || true
    fi
fi
VERSION="${VERSION:-unknown}"

# ─── Parse CLI arguments ───
ARG_STACK=""
ARG_NAME=""
ARG_GLOBAL=""
ARG_AUTO=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --auto)
            ARG_AUTO=true
            shift
            ;;
        --stack)
            ARG_STACK="$2"
            shift 2
            ;;
        --name)
            ARG_NAME="$2"
            shift 2
            ;;
        --global)
            ARG_GLOBAL="y"
            shift
            ;;
        --no-global)
            ARG_GLOBAL="n"
            shift
            ;;
        -h|--help)
            echo "Usage: bash init.sh [options]"
            echo ""
            echo "Options:"
            echo "  --auto              Non-interactive with defaults (stack=7, name=dirname, no global)"
            echo "  --stack <choices>   Stack selection: 1-7, space-separated (e.g., --stack \"3 4\")"
            echo "  --name <name>       Project name (default: directory name)"
            echo "  --global            Install global rules to ~/.claude/CLAUDE.md"
            echo "  --no-global         Skip global rules install"
            echo "  -h, --help          Show this help"
            echo ""
            echo "Stacks: 1=RTL  2=Embedded  3=Python  4=JS/TS  5=Mobile  6=Fullstack  7=General"
            exit 0
            ;;
        *)
            echo "Unknown option: $1 (use --help for usage)"
            exit 1
            ;;
    esac
done

# --auto sets defaults for anything not explicitly provided
if [ "$ARG_AUTO" = true ]; then
    [ -z "$ARG_STACK" ] && ARG_STACK="7"
    [ -z "$ARG_GLOBAL" ] && ARG_GLOBAL="n"
fi

# ─── Colors ───
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Support both direct execution and npm (via CC_DISCIPLINE_PKG_DIR)
if [ -n "$CC_DISCIPLINE_PKG_DIR" ]; then
    SCRIPT_DIR="$CC_DISCIPLINE_PKG_DIR"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
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
elif [ -f ".claude/hooks/streak-breaker.sh" ] || [ -f ".claude/hooks/pre-edit-guard.sh" ] || [ -f ".claude/hooks/session-start.sh" ] || [ -f ".claude/hooks/phase-gate.sh" ]; then
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
if [ -n "$ARG_STACK" ]; then
    STACK_CHOICES="$ARG_STACK"
    echo -e "Stack: ${GREEN}${STACK_CHOICES}${NC} (from CLI)"
elif [ "$INSTALL_MODE" = "fresh" ]; then
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
if [ -n "$ARG_NAME" ]; then
    PROJECT_NAME="$ARG_NAME"
    echo -e "Project name: ${GREEN}${PROJECT_NAME}${NC} (from CLI)"
elif [ "$INSTALL_MODE" = "fresh" ]; then
    DEFAULT_NAME=$(basename "$PROJECT_DIR")
    if [ "$ARG_AUTO" = true ]; then
        PROJECT_NAME="$DEFAULT_NAME"
        echo -e "Project name: ${GREEN}${PROJECT_NAME}${NC} (auto)"
    else
        read -p "Project name [$DEFAULT_NAME]: " PROJECT_NAME
        PROJECT_NAME=${PROJECT_NAME:-$DEFAULT_NAME}
    fi
else
    # Try to extract from existing CLAUDE.md: "# MyProject — CLAUDE.md"
    PROJECT_NAME=""
    if [ -f "CLAUDE.md" ]; then
        PROJECT_NAME=$(head -1 CLAUDE.md | sed 's/^# //;s/ — CLAUDE.md$//' 2>/dev/null)
    fi
    if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "[PROJECT_NAME]" ]; then
        DEFAULT_NAME=$(basename "$PROJECT_DIR")
        if [ "$ARG_AUTO" = true ]; then
            PROJECT_NAME="$DEFAULT_NAME"
            echo -e "Project name: ${GREEN}${PROJECT_NAME}${NC} (auto)"
        else
            read -p "Project name [$DEFAULT_NAME]: " PROJECT_NAME
            PROJECT_NAME=${PROJECT_NAME:-$DEFAULT_NAME}
        fi
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
cp "$SCRIPT_DIR/templates/.claude/rules/07-integrity.md" .claude/rules/

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
cp "$SCRIPT_DIR/templates/.claude/hooks/session-start.sh" .claude/hooks/
cp "$SCRIPT_DIR/templates/.claude/hooks/phase-gate.sh" .claude/hooks/
cp "$SCRIPT_DIR/templates/.claude/hooks/git-guard.sh" .claude/hooks/
cp "$SCRIPT_DIR/templates/.claude/hooks/action-counter.sh" .claude/hooks/
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
          def is_cc: .hooks | any(.command | test("pre-edit-guard|streak-breaker|post-error-remind|session-start|phase-gate|action-counter"));
          def merge($ev): (($e.hooks[$ev] // []) | map(select(is_cc | not))) + ($t.hooks[$ev] // []);
          $e * {
            hooks: (($e.hooks // {}) + {
              SessionStart: merge("SessionStart"),
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
# Install every skill directory under templates/ — no per-skill enumeration,
# so adding a new skill needs zero changes here.
#
# Copy into an EXPLICIT destination directory. Do not use `cp -r "$skill_dir"
# .claude/skills/` here: the `*/` glob gives $skill_dir a trailing slash, and
# GNU and BSD cp disagree about what that means. GNU copies the directory;
# BSD (macOS) copies its *contents*, so every skill's SKILL.md landed on top of
# the previous one at .claude/skills/SKILL.md and no skill was ever updated.
# Shipped broken in v2.11.0 (the "directory-driven install" change) and fixed in
# v2.12.1. Symptom on an affected machine: a stray .claude/skills/SKILL.md plus
# skill dirs frozen at their first-install date. status/doctor could not catch
# it because they glob `skills/*/` and a bare file is not a directory.
# Skills are NOT force-overwritten. Users legitimately tune them per repo
# (/self-check's "Project-specific Checks" section exists precisely to be filled
# in), and until v2.12.2 every upgrade silently replaced those edits — a 73KB
# hand-written self-check was wiped twice in one day before this was fixed.
#
# The dpkg-conffile approach: remember the hash of the template WE installed. On
# the next upgrade, if the file on disk still matches that hash the user never
# touched it and we can update freely; if it differs the user owns it, so we keep
# their file and drop the new template beside it as SKILL.md.new.
#
# The manifest hash is always set to the template we shipped this run, including
# in the preserved case. That is what makes adoption self-healing: if the user
# later replaces their file with the .new one, the next run sees disk == manifest
# and resumes silent updates.
SKILLS_MANIFEST=".claude/.cc-discipline-skills.manifest"
NEW_MANIFEST=$(mktemp 2>/dev/null || echo ".claude/.skills-manifest.tmp")
PRESERVED_SKILLS=""
RETIRED_SKILLS=""
RETIRED_PARTIAL=""
KEPT_RETIRED=""
# Snapshot the manifest before the install loop overwrites it. The retirement
# pass further down needs the OLD record to tell "we installed this" apart from
# "the user wrote it themselves".
OLD_MANIFEST=$(mktemp 2>/dev/null || echo ".claude/.skills-manifest.old")
[ -f "$SKILLS_MANIFEST" ] && cp "$SKILLS_MANIFEST" "$OLD_MANIFEST"

# Emit "<algo>:<digest>", never a bare digest. The fallback chain below resolves
# differently depending on what is installed, so a manifest that stores only the
# digest silently mis-compares the moment tool availability changes — the same
# class of environment drift that made the jq-only reads fail. When that happens
# every recorded hash mismatches, every retired skill looks user-modified, and
# the retirement pass does nothing. (fixed 2026-08-28, before 2.13.0 shipped.)
# sha256sum and `shasum -a 256` produce identical digests, so both record sha256.
_cc_hash() {
    if command -v sha256sum >/dev/null 2>&1; then echo "sha256:$(sha256sum "$1" | cut -d' ' -f1)"
    elif command -v shasum >/dev/null 2>&1; then echo "sha256:$(shasum -a 256 "$1" | cut -d' ' -f1)"
    elif command -v md5sum >/dev/null 2>&1; then echo "md5:$(md5sum "$1" | cut -d' ' -f1)"
    elif command -v md5 >/dev/null 2>&1; then echo "md5:$(md5 -q "$1")"
    else echo "cksum:$(cksum "$1" | cut -d' ' -f1)"; fi
}

# True when manifest entry $2 still describes the current content of file $1.
# Handles the "<algo>:<digest>" form written from 2.13.0 and the bare digest
# written by 2.12.2/2.12.3: for a legacy entry the algorithm is unknown, so try
# each available one and accept any match rather than calling the file modified.
_cc_hash_matches() {
    _f="$1"; _rec="$2"
    [ -n "$_rec" ] || return 1
    case "$_rec" in
        *:*) [ "$(_cc_hash "$_f")" = "$_rec" ] && return 0; return 1 ;;
    esac
    for _algo in sha256sum shasum md5sum md5 cksum; do
        command -v "$_algo" >/dev/null 2>&1 || continue
        case "$_algo" in
            sha256sum) _got=$(sha256sum "$_f" | cut -d' ' -f1) ;;
            shasum)    _got=$(shasum -a 256 "$_f" | cut -d' ' -f1) ;;
            md5sum)    _got=$(md5sum "$_f" | cut -d' ' -f1) ;;
            md5)       _got=$(md5 -q "$_f") ;;
            cksum)     _got=$(cksum "$_f" | cut -d' ' -f1) ;;
        esac
        [ "$_got" = "$_rec" ] && return 0
    done
    return 1
}

for skill_dir in "$SCRIPT_DIR"/templates/.claude/skills/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    mkdir -p ".claude/skills/$skill_name"
    skill_status="updated"

    for src in "$skill_dir"*; do
        [ -f "$src" ] || continue
        base=$(basename "$src")
        rel="$skill_name/$base"
        dst=".claude/skills/$rel"
        tpl_hash=$(_cc_hash "$src")

        if [ ! -f "$dst" ]; then
            cp "$src" "$dst"                       # new file — nothing to protect
        else
            recorded=$(grep "^$rel " "$SKILLS_MANIFEST" 2>/dev/null | head -1 | cut -d' ' -f2)
            if _cc_hash_matches "$dst" "$tpl_hash"; then
                :                                  # already current
            elif _cc_hash_matches "$dst" "$recorded"; then
                cp "$src" "$dst"                   # pristine older version — safe
            elif [ -z "$recorded" ]; then
                # No manifest yet (first run on an existing install) and the file
                # differs from the template. Cannot tell "older version" from
                # "user edited", so assume the user's work matters.
                cp "$src" "$dst.new"
                skill_status="preserved"
            else
                cp "$src" "$dst.new"               # user-modified — keep theirs
                skill_status="preserved"
            fi
        fi
        echo "$rel $tpl_hash" >> "$NEW_MANIFEST"
    done

    if [ "$skill_status" = "preserved" ]; then
        PRESERVED_SKILLS="$PRESERVED_SKILLS $skill_name"
        echo -e "   ${YELLOW}~ /$skill_name (your version kept; new template at SKILL.md.new)${NC}"
    else
        echo "   ✓ /$skill_name"
    fi
done

[ -f "$NEW_MANIFEST" ] && mv "$NEW_MANIFEST" "$SKILLS_MANIFEST"

# ─── Retire skills that upstream removed ───
# The install loop only ever copies, so a skill deleted from templates/ (as
# /finish and /retro were in v2.13.0) would otherwise sit in every existing
# install forever. Same conffile rule as the overwrite guard above: delete only
# what we installed and the user never touched. Anything modified is kept and
# reported. An install with no prior manifest is left alone entirely — without
# the old hashes there is no way to tell our copy from the user's own work.
if [ -s "$OLD_MANIFEST" ]; then
    for old_skill in $(cut -d' ' -f1 "$OLD_MANIFEST" | cut -d'/' -f1 | sort -u); do
        [ -d "$SCRIPT_DIR/templates/.claude/skills/$old_skill" ] && continue
        [ -d ".claude/skills/$old_skill" ] || continue
        skill_modified=false
        while read -r rel rec_hash; do
            case "$rel" in "$old_skill"/*) ;; *) continue ;; esac
            [ -f ".claude/skills/$rel" ] || continue
            _cc_hash_matches ".claude/skills/$rel" "$rec_hash" || skill_modified=true
        done < "$OLD_MANIFEST"
        if [ "$skill_modified" = true ]; then
            KEPT_RETIRED="$KEPT_RETIRED $old_skill"
            # Carry the old entries into the new manifest. Without this the skill
            # never appears in a manifest again, so a later upgrade cannot tell
            # our copy from the user's and it is frozen in place permanently.
            grep "^$old_skill/" "$OLD_MANIFEST" >> "$SKILLS_MANIFEST" 2>/dev/null
        else
            # Delete only the files the manifest recorded, then the directory if
            # that leaves it empty. A blanket rm -rf would also destroy files a
            # user put inside the skill directory that we never installed and
            # therefore cannot account for.
            while read -r rel _; do
                case "$rel" in "$old_skill"/*) ;; *) continue ;; esac
                rm -f ".claude/skills/$rel"
            done < "$OLD_MANIFEST"
            if rmdir ".claude/skills/$old_skill" 2>/dev/null; then
                RETIRED_SKILLS="$RETIRED_SKILLS $old_skill"
            else
                RETIRED_PARTIAL="$RETIRED_PARTIAL $old_skill"
            fi
        fi
    done
fi
rm -f "$OLD_MANIFEST" 2>/dev/null

if [ -n "$RETIRED_SKILLS" ]; then
    echo -e "   ${YELLOW}Retired upstream, removed:${RETIRED_SKILLS}${NC}"
fi
if [ -n "$RETIRED_PARTIAL" ]; then
    echo -e "   ${YELLOW}Retired upstream; our files removed but directory kept (it holds files we did not install):${RETIRED_PARTIAL}${NC}"
fi
if [ -n "$KEPT_RETIRED" ]; then
    echo -e "   ${YELLOW}Retired upstream but kept — you modified them:${KEPT_RETIRED}${NC}"
    echo -e "   ${YELLOW}Delete by hand once you no longer need them.${NC}"
fi

if [ -n "$PRESERVED_SKILLS" ]; then
    echo -e "   ${YELLOW}Locally modified skills were not overwritten:${PRESERVED_SKILLS}${NC}"
    echo -e "   ${YELLOW}Compare with: diff .claude/skills/<name>/SKILL.md{,.new}${NC}"
    echo -e "   ${YELLOW}Take the new one with: mv .claude/skills/<name>/SKILL.md{.new,}${NC}"
fi

# Clean up the stray file left behind by the v2.11.0–v2.12.0 bug above. A bare
# SKILL.md directly under skills/ is never a valid skill (skills live in
# subdirectories), so this only ever removes that debris.
if [ -f ".claude/skills/SKILL.md" ]; then
    rm -f ".claude/skills/SKILL.md"
    echo -e "   ${YELLOW}✓ removed stray .claude/skills/SKILL.md (v2.11.0 macOS install bug)${NC}"
fi

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

# ─── Install auto memory (symlink to .claude/memory/) ───
echo -e "${GREEN}Installing auto memory...${NC}"
MEMORY_PROJECT_KEY=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
MEMORY_CLAUDE_DIR="$HOME/.claude/projects/${MEMORY_PROJECT_KEY}"
MEMORY_LOCAL_DIR="$PROJECT_DIR/.claude/memory"

# Ensure local .claude/memory/ exists in repo
mkdir -p "$MEMORY_LOCAL_DIR"

# If MEMORY.md doesn't exist locally, seed from template
if [ ! -f "$MEMORY_LOCAL_DIR/MEMORY.md" ]; then
    cp "$SCRIPT_DIR/templates/memory/MEMORY.md" "$MEMORY_LOCAL_DIR/MEMORY.md"
    echo "   ✓ Memory template installed to .claude/memory/MEMORY.md"
else
    echo -e "   ${YELLOW}.claude/memory/MEMORY.md already exists (preserved)${NC}"
fi

# Create symlink: ~/.claude/projects/<key>/memory → .claude/memory/
mkdir -p "$MEMORY_CLAUDE_DIR"
if [ -L "$MEMORY_CLAUDE_DIR/memory" ]; then
    # Symlink already exists — update it
    rm "$MEMORY_CLAUDE_DIR/memory"
    ln -s "$MEMORY_LOCAL_DIR" "$MEMORY_CLAUDE_DIR/memory"
    echo "   ✓ Memory symlink updated"
elif [ -d "$MEMORY_CLAUDE_DIR/memory" ]; then
    # Existing real directory — migrate files then replace with symlink
    for f in "$MEMORY_CLAUDE_DIR/memory/"*; do
        [ -f "$f" ] || continue
        fname=$(basename "$f")
        if [ ! -f "$MEMORY_LOCAL_DIR/$fname" ]; then
            cp "$f" "$MEMORY_LOCAL_DIR/$fname"
        fi
    done
    rm -rf "$MEMORY_CLAUDE_DIR/memory"
    ln -s "$MEMORY_LOCAL_DIR" "$MEMORY_CLAUDE_DIR/memory"
    echo "   ✓ Existing memory migrated to .claude/memory/ and symlinked"
else
    ln -s "$MEMORY_LOCAL_DIR" "$MEMORY_CLAUDE_DIR/memory"
    echo "   ✓ Memory symlinked: ~/.claude/projects/.../ → .claude/memory/"
fi

# ─── Install global rules (optional) ───
if [ -n "$ARG_GLOBAL" ]; then
    REPLY="$ARG_GLOBAL"
else
    echo ""
    echo -e "${BLUE}Install global rules to ~/.claude/CLAUDE.md?${NC}"
    echo "  (Global rules apply to all projects, only needs to be installed once)"
    read -p "Install global rules? (y/N) " -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p ~/.claude
    if [ -f ~/.claude/CLAUDE.md ]; then
        echo -e "${YELLOW}  Existing ~/.claude/CLAUDE.md found, backing up to ~/.claude/CLAUDE.md.bak${NC}"
        cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak
    fi
    cp "$SCRIPT_DIR/global/CLAUDE.md" ~/.claude/CLAUDE.md
    echo -e "${GREEN}  ✓ Global rules installed${NC}"
fi

# ─── Install status line (optional) ───
GLOBAL_SETTINGS="$HOME/.claude/settings.json"
HAS_STATUSLINE=false
if [ -f "$GLOBAL_SETTINGS" ] && command -v jq &>/dev/null; then
    if jq -e '.statusLine' "$GLOBAL_SETTINGS" &>/dev/null; then
        HAS_STATUSLINE=true
    fi
elif [ -f "$GLOBAL_SETTINGS" ] && grep -q '"statusLine"' "$GLOBAL_SETTINGS" 2>/dev/null; then
    HAS_STATUSLINE=true
fi

if [ "$HAS_STATUSLINE" = false ]; then
    if [ "$ARG_AUTO" = true ]; then
        # Auto mode: skip statusline (don't install without asking)
        true
    else
        echo ""
        echo -e "${BLUE}Install ccstatusline? (shows model, context %, git branch in terminal)${NC}"
        echo "  This adds a status line to all Claude Code sessions via ~/.claude/settings.json"
        read -p "Install status line? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p ~/.claude
            if [ -f "$GLOBAL_SETTINGS" ]; then
                # Merge statusLine into existing settings
                if command -v jq &>/dev/null; then
                    EXISTING=$(cat "$GLOBAL_SETTINGS")
                    echo "$EXISTING" | jq '. + {"statusLine": {"type": "command", "command": "npx -y ccstatusline@latest", "padding": 0}}' > "$GLOBAL_SETTINGS"
                else
                    # No jq — warn user to add manually
                    echo -e "${YELLOW}  jq not found — please add statusLine to ~/.claude/settings.json manually:${NC}"
                    echo '  "statusLine": {"type": "command", "command": "npx -y ccstatusline@latest", "padding": 0}'
                fi
            else
                # No existing settings — create new
                cat > "$GLOBAL_SETTINGS" <<'SEOF'
{
  "statusLine": {
    "type": "command",
    "command": "npx -y ccstatusline@latest",
    "padding": 0
  }
}
SEOF
            fi
            echo -e "${GREEN}  ✓ Status line installed (run 'npx -y ccstatusline@latest' once to configure widgets)${NC}"
        fi
    fi
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
    echo -e "  ${GREEN}.claude/hooks/${NC}               ← 7 discipline hooks (edit guard, streak breaker, git guard, phase gate, action counter, error remind, session start)"
    echo -e "  ${GREEN}.claude/agents/${NC}              ← Reviewer & investigator subagents"
    echo -e "  ${GREEN}.claude/skills/${NC}              ← Skills (run 'npx cc-discipline status' to list)"
    echo -e "  ${GREEN}.claude/settings.json${NC}        ← Hooks configuration"
    echo -e "  ${GREEN}docs/progress.md${NC}             ← Progress log (maintained by Claude)"
    echo -e "  ${GREEN}docs/debug-log.md${NC}            ← Debug log (maintained by Claude)"
    echo -e "  ${GREEN}.claude/memory/${NC}              ← Auto memory (symlinked, lives in repo)"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Edit CLAUDE.md and fill in the [TODO] sections with project info"
    echo "  2. Review rules in .claude/rules/stacks/ and adjust as needed"
    echo "  3. For complex tasks, use: /loop 10m /self-check"
    echo "  4. Start working with Claude Code!"
else
    echo -e "What was done:"
    echo -e "  ${GREEN}.claude/rules/${NC}               ← Discipline rules installed/updated"
    echo -e "  ${GREEN}.claude/hooks/${NC}               ← Hook scripts installed/updated"
    echo -e "  ${GREEN}.claude/agents/${NC}              ← Subagents installed/updated"
    echo -e "  ${GREEN}.claude/skills/${NC}              ← Skills installed/updated (run 'npx cc-discipline status' to list)"
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
