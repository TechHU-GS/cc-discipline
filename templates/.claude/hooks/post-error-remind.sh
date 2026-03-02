#!/bin/bash
# post-error-remind.sh — PostToolUse / PostToolUseFailure hook
# Detects error patterns in Bash output and reminds Claude to follow debugging discipline
#
# For PostToolUse: error content is in .tool_response
# For PostToolUseFailure: error content is in .error
#
# Uses exit 2 + stderr to inject reminder into Claude's context
# (exit 0 stdout is silent for Post hooks)

# Read the tool output from stdin (JSON)
RAW_INPUT=$(cat)

# Extract error content from JSON
OUTPUT=""
if command -v jq &>/dev/null; then
    # PostToolUseFailure uses .error, PostToolUse uses .tool_response
    OUTPUT=$(echo "$RAW_INPUT" | jq -r '.error // empty' 2>/dev/null)
    if [ -z "$OUTPUT" ]; then
        OUTPUT=$(echo "$RAW_INPUT" | jq -r '.tool_response.output // empty' 2>/dev/null)
    fi
fi

# Fallback
if [ -z "$OUTPUT" ]; then
    OUTPUT="$RAW_INPUT"
fi

# Detect common error patterns
HAS_ERROR=false
ERROR_TYPE=""

if echo "$OUTPUT" | grep -qi "error\|FAILED\|failure\|traceback\|exception\|panic\|segfault\|abort"; then
    HAS_ERROR=true
fi

if echo "$OUTPUT" | grep -qi "compile.*error\|syntax.*error\|build.*fail"; then
    ERROR_TYPE="build"
fi

if echo "$OUTPUT" | grep -qi "test.*fail\|FAILED\|AssertionError\|assert.*fail\|Expected.*but"; then
    ERROR_TYPE="test"
fi

if echo "$OUTPUT" | grep -qi "segfault\|segmentation fault\|bus error\|core dump\|abort"; then
    ERROR_TYPE="crash"
fi

if [ "$HAS_ERROR" = true ]; then
    REMINDER="ERROR DETECTED. Follow debugging discipline: 1. Do NOT modify code immediately 2. Fully understand the error message 3. List possible causes (>=2) 4. Record in docs/debug-log.md 5. Verify hypotheses before fixing"

    if [ "$ERROR_TYPE" = "test" ]; then
        REMINDER="$REMINDER. WARNING: Test failure — do NOT change the test to make it pass! First determine if it's a code bug or an outdated test."
    fi

    if [ "$ERROR_TYPE" = "crash" ]; then
        REMINDER="$REMINDER. WARNING: Crash/segfault — may involve memory issues. Check pointers, array bounds, uninitialized variables."
    fi

    # exit 2 + stderr: inject message into Claude's context
    echo "$REMINDER" >&2
    exit 2
fi

# No error detected, silent pass
exit 0
