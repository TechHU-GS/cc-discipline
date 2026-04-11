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
fi

# Fallback if jq unavailable
if [ -z "$OUTPUT" ]; then
    OUTPUT="$RAW_INPUT"
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
    REMINDER="Error encountered — debugging checklist: 1. Resist modifying code immediately 2. Fully understand the error message 3. List >=3 possible causes — label them hypotheses, not root cause 4. Record in docs/debug-log.md 5. Eliminate >=2 hypotheses with evidence before identifying root cause 6. Only then fix. Important: after seeing one error, the first explanation is a hypothesis, not a conclusion. Say 'possible cause' until you have elimination evidence."

    if [ "$ERROR_TYPE" = "test" ]; then
        REMINDER="$REMINDER Note: Test failure — before changing the test, first determine if it's a code bug or an outdated test."
    fi

    if [ "$ERROR_TYPE" = "crash" ]; then
        REMINDER="$REMINDER Note: Crash/segfault — may involve memory issues."
    fi

    echo "$REMINDER" >&2
    exit 2
fi

exit 0
