#!/usr/bin/env bash
# cc-discipline CLI entry point
# Resolves symlinks (npm bin creates symlinks) to find the real package directory

set -e

# Resolve the real path of this script (works through npm symlinks)
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    # If SOURCE is relative, resolve it relative to DIR
    [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
BIN_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
PKG_DIR="$(cd "$BIN_DIR/.." && pwd)"

export CC_DISCIPLINE_PKG_DIR="$PKG_DIR"

# ─── Version ───
VERSION=$(node -p "require('$PKG_DIR/package.json').version" 2>/dev/null || echo "unknown")

# ─── Route subcommands ───
COMMAND="${1:-init}"

case "$COMMAND" in
    init)
        shift 2>/dev/null || true
        bash "$PKG_DIR/init.sh" "$@"
        ;;
    upgrade)
        shift
        bash "$PKG_DIR/init.sh" --auto "$@"
        ;;
    status)
        bash "$PKG_DIR/lib/status.sh"
        ;;
    doctor)
        bash "$PKG_DIR/lib/doctor.sh"
        ;;
    add-stack)
        shift
        if [ -z "$1" ]; then
            echo "Usage: cc-discipline add-stack <numbers>"
            echo "  e.g.: cc-discipline add-stack 3 4"
            exit 1
        fi
        bash "$PKG_DIR/init.sh" --stack "$*" --no-global
        ;;
    remove-stack)
        shift
        bash "$PKG_DIR/lib/stack-remove.sh" "$@"
        ;;
    -v|--version|version)
        echo "cc-discipline v${VERSION}"
        ;;
    -h|--help|help)
        cat <<EOF
cc-discipline v${VERSION} — Discipline framework for Claude Code

Usage: cc-discipline <command> [options]

Commands:
  init [options]        Install discipline into current project (default)
  upgrade               Upgrade rules/hooks (shortcut for init --auto)
  add-stack <numbers>   Add stack rules (e.g., add-stack 3 4)
  remove-stack <numbers> Remove stack rules
  status                Show installed version, stacks, and hooks
  doctor                Check installation integrity
  version               Show version

Init options:
  --auto                Non-interactive with defaults
  --stack <choices>     Stack selection: 1-7, space-separated
  --name <name>         Project name (default: directory name)
  --global              Install global rules to ~/.claude/CLAUDE.md
  --no-global           Skip global rules install

Stacks:
  1=RTL  2=Embedded  3=Python  4=JS/TS  5=Mobile  6=Fullstack  7=General

Examples:
  npx cc-discipline                           # Interactive setup
  npx cc-discipline init --auto               # Non-interactive defaults
  npx cc-discipline init --auto --stack "3 4"  # Python + JS/TS
  npx cc-discipline upgrade                   # Upgrade to latest
  npx cc-discipline status                    # Check what's installed
  npx cc-discipline doctor                    # Diagnose issues
EOF
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo "Run 'cc-discipline --help' for usage"
        exit 1
        ;;
esac
