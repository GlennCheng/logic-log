#!/usr/bin/env bash
set -euo pipefail

# ── 讀取 hook input ──────────────────────────────────────────
HOOK_INPUT=$(cat)
CLAUDE_SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // "unknown"')
SESSION_START=$(date +"%Y-%m-%d-%H-%M")

# ── 儲存目錄（可用環境變數覆蓋）────────────────────────────
LOG_DIR="${LOGIC_LOG_DIR:-$HOME/.claude/logic-logs}"
INDEX_FILE="$LOG_DIR/index.md"
THEORIES_FILE="$LOG_DIR/theories.md"
SESSION_FILE="$LOG_DIR/sessions/$CLAUDE_SESSION_ID.md"

# ── 初始化目錄與檔案 ─────────────────────────────────────────
mkdir -p "$LOG_DIR/sessions"

if [ ! -f "$INDEX_FILE" ]; then
    cat > "$INDEX_FILE" << 'EOF'
# Logic Log Index
<!-- 格式：#NNN | YYYY-MM-DD HH:MM | claude-session-id | YYYY-MM-DD-HH-MM | TYPE | 主題 | 理論 -->
EOF
fi

if [ ! -f "$THEORIES_FILE" ]; then
    cat > "$THEORIES_FILE" << 'EOF'
# Theory Ledger（理論圖鑑）
<!-- 格式：每個理論一個區塊。核心：通用說明（不含特定案例）。應用記錄：#NNN | TYPE | 專案 | claude-session-id | YYYY-MM-DD-HH-MM | Session大主題 | 當筆主題 | 描述 -->
EOF
fi

# ── 初始化 session 檔案（若不存在）───────────────────────
if [ ! -f "$SESSION_FILE" ]; then
    cat > "$SESSION_FILE" << EOF
# Logic Log — Session $CLAUDE_SESSION_ID
**開始時間：** $SESSION_START
**專案：**
EOF
fi

# ── 取得專案名稱 ──────────────────────────────────────────────
PROJECT=$(git rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null || basename "$PWD")

# ── 計算下一筆編號 ────────────────────────────────────────────
LATEST_NUM=$(grep -oP '(?<=^#)\d+' "$INDEX_FILE" 2>/dev/null | sort -n | tail -1 || echo "")
if [ -z "$LATEST_NUM" ]; then
    NEXT_NUM=1
else
    NEXT_NUM=$((LATEST_NUM + 1))
fi
NEXT_NUM_PADDED=$(printf '%03d' "$NEXT_NUM")

# ── 取得最近 5 筆記錄 ─────────────────────────────────────────
RECENT=$(grep -P '^#\d+' "$INDEX_FILE" 2>/dev/null | tail -5 || echo "（尚無記錄）")

# ── 組裝 context 字串 ─────────────────────────────────────────
CONTEXT=$(cat << CTXEOF
## Logic Log Session Context

**Claude Session ID：** $CLAUDE_SESSION_ID
**Session 開始時間：** $SESSION_START
**專案：** $PROJECT
**下一筆記錄從 #$NEXT_NUM_PADDED 開始**（session 內自行遞增）

**最近 5 筆記錄：**
$RECENT

---
當對話中出現分析推理、決策過程、多維度考量、或自我質疑修正時，請在回應末尾輸出邏輯記錄區塊（logic-log skill）。
CTXEOF
)

# ── 輸出 hook JSON ────────────────────────────────────────────
jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'

exit 0
