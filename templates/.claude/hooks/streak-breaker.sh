#!/bin/bash
# streak-breaker.sh — PreToolUse hook
# Tracks how many times the same file has been edited in this session
# Forces a stop when the pattern suggests mole-whacking
#
# Exit 0 + no output = silent allow
# Exit 0 + JSON stdout = allow with context injected to Claude
# Exit 2 + stderr = block operation, stderr shown to Claude

# Read tool input from stdin (JSON)
INPUT=$(cat)

# Extract session_id and file_path
if command -v jq &>/dev/null; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
else
    SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":\s*"[^"]*"' | head -1 | sed 's/"session_id":\s*"//;s/"//')
    FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":\s*"[^"]*"' | head -1 | sed 's/"file_path":\s*"//;s/"//')
fi

SESSION_ID="${SESSION_ID:-unknown-session}"
COUNTER_DIR="/tmp/cc-discipline-${SESSION_ID}"
mkdir -p "$COUNTER_DIR" 2>/dev/null

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Allow docs/ files
if echo "$FILE_PATH" | grep -q "^docs/\|/docs/"; then
    exit 0
fi

# Counter logic
SAFE_NAME=$(echo "$FILE_PATH" | tr '/' '_')
COUNTER_FILE="$COUNTER_DIR/$SAFE_NAME"

if [ -f "$COUNTER_FILE" ]; then
    COUNT=$(cat "$COUNTER_FILE")
else
    COUNT=0
fi

COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

WARN_THRESHOLD=3
STOP_THRESHOLD=5

# Hard stop: exit 2 + stderr
if [ "$COUNT" -ge "$STOP_THRESHOLD" ]; then
    cat >&2 <<EOF
🛑 打地鼠警告（硬停止）
文件 $FILE_PATH 已被编辑 $COUNT 次。
你在反复修补症状而不是解决根因。
强制要求：
  1. 立即停止修改此文件
  2. 回顾所有 $COUNT 次修改的目的
  3. 寻找共同根因
  4. 向用户汇报发现，等待指导
解除方法：用户确认方向后，删除 $COUNTER_FILE 重置计数
EOF
    exit 2
fi

# Warning: exit 0 + JSON stdout with additionalContext
if [ "$COUNT" -ge "$WARN_THRESHOLD" ]; then
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "⚠️ 注意：文件 $FILE_PATH 已被编辑 $COUNT 次。检查你是否在打地鼠？这些修改是否指向同一个根因？再编辑 $((STOP_THRESHOLD - COUNT)) 次将触发硬停止。"
  }
}
EOF
    exit 0
fi

# Silent allow
exit 0
