#!/bin/bash
# post-error-remind.sh — PostToolUse / PostToolUseFailure hook
# Detects error patterns in Bash output and reminds Claude to follow debugging discipline
#
# NOTE: We use exit 2 intentionally for Post hooks.
# exit 0 is completely silent — no way to inject text from Post hooks.
# exit 2 + stderr is the ONLY mechanism to show reminders to Claude after tool execution.
# The tool has already executed — exit 2 doesn't block execution, it injects the message.
#
# Design principles:
#   - Only match REAL error patterns, not the word "error" in any context
#   - Skip non-Bash tools (Edit/Write/Read have their own error handling)
#   - Skip truncated output (large output ≠ error)
#   - Use specific patterns: line-start anchors, known failure formats
#
# exit 0 = silent pass (normal for Post hooks)
# exit 2 + stderr = inject reminder into Claude's context

RAW_INPUT=$(cat)

# Extract tool name and response
TOOL_NAME=""
OUTPUT=""

if command -v jq &>/dev/null; then
    TOOL_NAME=$(echo "$RAW_INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
    # PostToolUseFailure uses .error, PostToolUse uses .tool_response
    OUTPUT=$(echo "$RAW_INPUT" | jq -r '.error // empty' 2>/dev/null)
    if [ -z "$OUTPUT" ]; then
        OUTPUT=$(echo "$RAW_INPUT" | jq -r '.tool_response.output // empty' 2>/dev/null)
    fi
else
    # jq is absent on Windows Git Bash. Extract the same two fields with sed.
    # Unescape \n so the line-anchored patterns below (^ERROR, ^Traceback, ...)
    # still work.
    TOOL_NAME=$(echo "$RAW_INPUT" | sed -n -E 's/.*"tool_name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -1)
    OUTPUT=$(echo "$RAW_INPUT" | sed -n -E 's/.*[{,][[:space:]]*"(error|output)"[[:space:]]*:[[:space:]]*"(.*)".*/\2/p' | head -1 \
        | sed 's/[\]n/\
/g; s/[\]"/"/g')
fi

# NEVER match against the raw JSON envelope. The command text lives in there
# too, so `grep -rn "permission denied" logs/` used to flag itself — and with
# tool_name unresolved the non-Bash early-exit below never fired either, so this
# hook lectured on clean Read calls. Both were the old `OUTPUT="$RAW_INPUT"`
# fallback. If the tool's own output can't be isolated, stay silent: a false
# positive here costs a turn and misleads, so silence is the safe direction.
# (fixed 2026-07-30 — verified with jq absent, see docs/progress.md)
if [ -z "$OUTPUT" ]; then
    exit 0
fi

# --- Early exits for known non-error situations ---

# Only check Bash tool output
if [ -n "$TOOL_NAME" ] && [ "$TOOL_NAME" != "Bash" ]; then
    exit 0
fi

# Truncated output is not an error
if echo "$OUTPUT" | grep -q "Output too large"; then
    exit 0
fi

# Successful git operations
if echo "$OUTPUT" | grep -qE "^\[main |^\[master |^On branch |^nothing to commit|^Already up to date"; then
    exit 0
fi

# --- Detect REAL error patterns ---

HAS_ERROR=false
ERROR_TYPE=""

# Build/compile errors (line-start or known formats)
if echo "$OUTPUT" | grep -qE "^ERROR |^\[ERROR\]|BUILD FAILURE|compilation error|cannot find symbol|package .* does not exist"; then
    HAS_ERROR=true
    ERROR_TYPE="build"
fi

# Test failures (Maven/Gradle/Jest specific formats)
if echo "$OUTPUT" | grep -qE "Tests run:.*Failures: [1-9]|Tests:.*failed|FAILED!|BUILD FAILURE.*test"; then
    HAS_ERROR=true
    ERROR_TYPE="test"
fi

# Runtime crashes
if echo "$OUTPUT" | grep -qiE "segmentation fault|bus error|core dumped|SIGABRT|SIGSEGV|killed.*signal"; then
    HAS_ERROR=true
    ERROR_TYPE="crash"
fi

# Shell errors (command failures)
if echo "$OUTPUT" | grep -qE "command not found|permission denied|cannot execute|not a git repository"; then
    HAS_ERROR=true
    ERROR_TYPE="system"
fi

# Stack traces (Java, Python, Node)
if echo "$OUTPUT" | grep -qE "^Exception in thread|^Traceback \(most recent|^Caused by:.*Exception"; then
    HAS_ERROR=true
    ERROR_TYPE="exception"
fi

# npm/yarn explicit failure
if echo "$OUTPUT" | grep -qE "^npm ERR!|^error .*ENOENT|FATAL ERROR"; then
    HAS_ERROR=true
    ERROR_TYPE="build"
fi

# --- Emit reminder if error detected ---

if [ "$HAS_ERROR" = true ]; then
    # Keep this to ONE line. The hypothesis discipline itself lives in the
    # always-injected rules (00-core §6, 01-debugging) — re-injecting the full
    # ">=3 causes / record in debug-log / eliminate >=2" ritual on every error
    # duplicated them and pushed toward over-verification. Trimmed 2026-07-30.
    REMINDER="Error detected: the first explanation that comes to mind is a hypothesis, not the root cause. Read the actual error before changing code."

    if [ "$ERROR_TYPE" = "test" ]; then
        REMINDER="$REMINDER Test failure — decide whether the code is wrong or the test is outdated before touching either."
    fi

    echo "$REMINDER" >&2
    exit 2
fi

exit 0
