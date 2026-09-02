#!/bin/bash
# Behaviour matrix for pre-edit-guard.sh — the exemption decisions.
#
# Why this exists: v2.13.5 replaced three `echo | grep` pipelines and one
# `basename` with `case` and parameter expansion, which cut the cost of deciding
# "not my business" from ~297ms to ~60ms on Git Bash. Glob matching and ERE are
# different engines, so a change like that needs a matrix, exactly as git-guard's
# does. Run it after ANY change to the exemption patterns.
#
# How a non-exempt file is made observable: the hook's debug-log check emits an
# additionalContext note on stdout when a project's docs/debug-log.md has more
# pending hypotheses than confirmed ones. So against the fixture below, an
# exempted path produces NO stdout and a non-exempt one produces a note.
#
# Usage: bash tests/pre-edit-guard-matrix.sh [path-to-pre-edit-guard.sh]
#        defaults to the templates/ copy; pass .claude/hooks/... for the install.

HOOK="${1:-templates/.claude/hooks/pre-edit-guard.sh}"
[ -f "$HOOK" ] || { echo "not found: $HOOK"; exit 1; }
HOOK=$(cd "$(dirname "$HOOK")" && pwd)/$(basename "$HOOK")

FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/docs"
cat > "$FIXTURE/docs/debug-log.md" <<'LOG'
# Debug Log

| hypothesis | status |
|---|---|
| the parser drops trailing CR | pending |
| the manifest is compared raw | pending |
LOG

PASS=0; FAIL=0

# $1 = expectation: exempt | checked
# $2 = file_path to feed the hook
check() {
    want="$1"; path="$2"
    payload="{\"session_id\":\"m\",\"cwd\":\"$FIXTURE\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$path\",\"old_string\":\"a\",\"new_string\":\"b\"}}"
    out=$(printf '%s' "$payload" | bash "$HOOK" 2>/dev/null)
    if [ -z "$out" ]; then got=exempt; else got=checked; fi
    if [ "$got" = "$want" ]; then
        PASS=$((PASS+1)); printf '  ok   %-8s %s\n' "$want" "$path"
    else
        FAIL=$((FAIL+1)); printf '  FAIL want=%-8s got=%-8s %s\n' "$want" "$got" "$path"
    fi
}

echo "--- must be exempt (hook has no business here) ---"
check exempt "docs/progress.md"
check exempt "$FIXTURE/docs/notes.txt"
check exempt "/home/u/project/docs/deep/nested.c"
check exempt "README.md"
check exempt "/src/config.JSON"
check exempt "/src/settings.yaml"
check exempt "/src/settings.yml"
check exempt "/src/pyproject.toml"
check exempt "/src/.editorconfig.cfg"
check exempt "/src/setup.ini"
check exempt "/src/my_test_helper.c"
check exempt "/src/SpecRunner.java"
check exempt "/src/TEST_util.py"

echo "--- must NOT be exempt (real source) ---"
check checked "/src/init.sh"
check checked "/src/main.c"
check checked "/src/handler.py"
check checked "/src/Makefile"
# 'docs' as a substring is not the docs/ directory — these must still be checked
check checked "/src/docsite/index.html"
check checked "/src/mydocs/thing.py"
check checked "/src/documentation.py"
# .markdown is deliberately not in the extension list; only .md is
check checked "/src/notes.markdown"

echo
echo "通过 $PASS / 失败 $FAIL"
[ "$FAIL" -eq 0 ]
