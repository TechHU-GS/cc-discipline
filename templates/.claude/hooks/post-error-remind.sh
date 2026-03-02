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
    REMINDER="🔴 检测到错误输出。按调试纪律执行：1.不要立即修改代码 2.先完整理解错误信息 3.列出可能的原因(≥2个) 4.记录到docs/debug-log.md 5.验证假设后再动手修复"

    if [ "$ERROR_TYPE" = "test" ]; then
        REMINDER="$REMINDER。⚠️ 测试失败 — 不要改测试来通过！先确认是代码bug还是测试过时。"
    fi

    if [ "$ERROR_TYPE" = "crash" ]; then
        REMINDER="$REMINDER。⚠️ 崩溃/段错误 — 可能涉及内存问题。检查指针、数组越界、未初始化变量。"
    fi

    # exit 2 + stderr: inject message into Claude's context
    echo "$REMINDER" >&2
    exit 2
fi

# No error detected, silent pass
exit 0
