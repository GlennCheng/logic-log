#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="${LOGIC_LOG_DIR:-$HOME/.claude/logic-logs}"
INDEX_FILE="$LOG_DIR/index.md"

# 若無 index 檔或無記錄，不顯示
if [ ! -f "$INDEX_FILE" ]; then
    exit 0
fi

# 取得最近 3 筆
RECENT=$(grep -E '^#[0-9]+' "$INDEX_FILE" 2>/dev/null | tail -3 || true)

if [ -z "$RECENT" ]; then
    exit 0
fi

# 格式化：#NNN 主題｜理論
FORMAT_LINE() {
    local line="$1"
    local num topic theories
    num=$(echo "$line" | cut -d'|' -f1 | tr -d ' ')
    topic=$(echo "$line" | cut -d'|' -f6 | xargs)
    theories=$(echo "$line" | cut -d'|' -f7 | xargs)
    echo "$num $topic｜$theories"
}

STATUS="💡"
while IFS= read -r line; do
    [ -z "$line" ] && continue
    STATUS="$STATUS $(FORMAT_LINE "$line")  ·"
done <<< "$RECENT"

# 移除最後的 ·
STATUS="${STATUS%  ·}"

echo "$STATUS"
exit 0
