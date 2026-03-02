#!/bin/bash
# post-error-remind.sh
# Triggered after Bash tool execution
# Detects error patterns and reminds Claude to follow debugging discipline
#
# This hook reads tool output and injects reminders when errors are detected

# Read the tool output from stdin
OUTPUT=$(cat)

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
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔴 检测到错误输出"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "提醒：按调试纪律执行 —"
    echo "  1. 不要立即修改代码"
    echo "  2. 先完整理解错误信息"
    echo "  3. 列出可能的原因（≥2个）"
    echo "  4. 记录到 docs/debug-log.md"
    echo "  5. 验证假设后再动手修复"

    if [ "$ERROR_TYPE" = "test" ]; then
        echo ""
        echo "⚠️ 这是测试失败 — 不要改测试来通过！先确认是代码 bug 还是测试过时。"
    fi

    if [ "$ERROR_TYPE" = "crash" ]; then
        echo ""
        echo "⚠️ 这是崩溃/段错误 — 可能涉及内存问题。仔细检查指针、数组越界、未初始化变量。"
    fi

    echo ""
fi

# Always exit 0 - this is advisory only, never blocks
exit 0
