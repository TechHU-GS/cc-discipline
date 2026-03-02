#!/bin/bash
# streak-breaker.sh
# Triggered before Edit/Write/MultiEdit operations
# Tracks how many times the same file has been edited in this session
# Forces a stop when the pattern suggests mole-whacking
#
# Uses a simple counter file in /tmp to track edits per session

COUNTER_DIR="/tmp/cc-discipline-$$"
mkdir -p "$COUNTER_DIR" 2>/dev/null

# Read tool input
INPUT=$(cat)

# Extract file path
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":\s*"[^"]*"' | head -1 | sed 's/"file_path":\s*"//;s/"//')

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Allow docs/ files (they're supposed to be updated frequently)
if echo "$FILE_PATH" | grep -q "^docs/\|/docs/"; then
    exit 0
fi

# Create a safe filename for the counter
SAFE_NAME=$(echo "$FILE_PATH" | tr '/' '_')
COUNTER_FILE="$COUNTER_DIR/$SAFE_NAME"

# Read current count
if [ -f "$COUNTER_FILE" ]; then
    COUNT=$(cat "$COUNTER_FILE")
else
    COUNT=0
fi

# Increment
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# Thresholds
WARN_THRESHOLD=3
STOP_THRESHOLD=5

if [ "$COUNT" -ge "$STOP_THRESHOLD" ]; then
    echo ""
    echo "🛑🛑🛑 打地鼠警告（硬停止）🛑🛑🛑"
    echo ""
    echo "文件 $FILE_PATH 已被编辑 $COUNT 次。"
    echo "这强烈暗示你在反复修补症状而不是解决根因。"
    echo ""
    echo "强制要求："
    echo "  1. 立即停止修改此文件"
    echo "  2. 回顾所有 $COUNT 次修改的目的"
    echo "  3. 寻找这些修改背后的共同根因"
    echo "  4. 向用户汇报你的发现，等待指导"
    echo ""
    echo "解除方法：用户确认方向后，删除 $COUNTER_FILE 重置计数"
    # Hard block - change to exit 0 if you prefer advisory only
    exit 1
fi

if [ "$COUNT" -ge "$WARN_THRESHOLD" ]; then
    echo ""
    echo "⚠️ 注意：文件 $FILE_PATH 已被编辑 $COUNT 次"
    echo "检查：你是在打地鼠吗？这些修改是否指向同一个根因？"
    echo "（再编辑 $((STOP_THRESHOLD - COUNT)) 次将触发硬停止）"
    echo ""
fi

exit 0
