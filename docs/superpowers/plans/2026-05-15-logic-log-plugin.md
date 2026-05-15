# Logic Log Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 實作 logic-log Claude Code plugin，自動捕捉對話中的邏輯思維與決策過程，分類為 SESSION / INSIGHT 兩種記錄類型，識別背後理論原理，並存入 `~/.claude/logic-logs/` 供跨 session 查詢。

**Architecture:** Skill + Hook 架構。SessionStart hook 注入 session context（編號起點、最近記錄），SKILL.md 定義 Claude 的記錄行為，/llog 指令提供查詢介面。所有資料存為 Markdown，零外部依賴。

**Tech Stack:** Bash（hook handlers）、Markdown（SKILL.md / command / storage）、jq（JSON 解析）、git（取得 project 名稱）

---

## 檔案結構

```
logic-log/
├── .claude-plugin/
│   └── plugin.json              ← Plugin 元數據（Task 1）
├── hooks/
│   └── hooks.json               ← Hook 宣告（Task 1）
├── hooks-handlers/
│   ├── session-start.sh         ← 初始化儲存 + 注入 context（Task 2）
│   └── statusline.sh            ← 狀態列顯示（Task 4）
├── skills/
│   └── logic-log/
│       └── SKILL.md             ← Claude 記錄行為定義（Task 3）
├── commands/
│   └── llog.md                  ← /llog 指令（Task 5）
└── README.md                    ← 安裝說明（Task 6）
```

**儲存（使用者機器，首次 session 自動建立）：**
```
~/.claude/logic-logs/            ← 可用 LOGIC_LOG_DIR 環境變數覆蓋
├── sessions/
│   ├── {claude-session-id}.md   ← 每個 session 一個檔（主要存取單位）
│   └── {claude-session-id}.md
├── index.md                     ← 全局摘要索引（含日期，供跨日查詢）
└── theories.md                  ← Theory Ledger 理論圖鑑
```

---

## Task 1：Plugin 骨架（plugin.json + hooks.json）

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `hooks/hooks.json`

- [ ] **Step 1：建立目錄**

```bash
mkdir -p .claude-plugin hooks hooks-handlers skills/logic-log commands
```

- [ ] **Step 2：寫 plugin.json**

建立 `.claude-plugin/plugin.json`：

```json
{
  "name": "logic-log",
  "version": "1.0.0",
  "description": "自動捕捉對話中的邏輯思維與決策過程，識別背後理論原理，建立可跨 session 引用的知識資產。",
  "author": {
    "name": "Glenn Cheng",
    "email": "glenn77217@gmail.com"
  }
}
```

- [ ] **Step 3：寫 hooks.json**

建立 `hooks/hooks.json`：

```json
{
  "description": "Logic Log hooks - 注入 session context 並顯示最近記錄",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks-handlers/session-start.sh\""
          }
        ]
      }
    ]
  }
}
```

> **Note：** Statusline hook 待確認 Claude Code 是否支援。Task 4 先實作 statusline.sh 腳本，hook 宣告視支援狀況補上。

- [ ] **Step 4：驗證 JSON 語法**

```bash
python3 -m json.tool .claude-plugin/plugin.json && echo "plugin.json OK"
python3 -m json.tool hooks/hooks.json && echo "hooks.json OK"
```

Expected output:
```
{
    "name": "logic-log",
    ...
}
plugin.json OK
{
    "description": "Logic Log hooks...",
    ...
}
hooks.json OK
```

- [ ] **Step 5：Commit**

```bash
git add .claude-plugin/hooks
git commit -m "feat: add logic-log plugin skeleton (plugin.json + hooks.json)"
```

---

## Task 2：session-start.sh（儲存初始化 + context 注入）

**Files:**
- Create: `hooks-handlers/session-start.sh`

session-start.sh 做四件事：
1. 讀取 Claude session ID 和產生 session 開始時間戳
2. 初始化 `~/.claude/logic-logs/` 目錄與三個檔案（若不存在）
3. 在當日 .md 檔案加上 Session 分隔標頭（方案 B）
4. 輸出 JSON context 注入（下一筆編號、最近 5 筆記錄摘要、session 資訊）

- [ ] **Step 1：建立 session-start.sh**

建立 `hooks-handlers/session-start.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

# ── 讀取 hook input ──────────────────────────────────────────
HOOK_INPUT=$(cat)
CLAUDE_SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // "unknown"')
SESSION_START=$(date +"%Y-%m-%d-%H-%M")
DATE=$(date +"%Y-%m-%d")
TIME=$(date +"%H:%M")

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
```

- [ ] **Step 2：設定執行權限**

```bash
chmod +x hooks-handlers/session-start.sh
```

- [ ] **Step 3：測試腳本輸出**

```bash
echo '{"session_id": "test-session-abc123"}' | bash hooks-handlers/session-start.sh
```

Expected：合法 JSON，包含 `hookSpecificOutput.additionalContext`，內容有「Logic Log Session Context」、「下一筆記錄從 #001 開始」。

- [ ] **Step 4：驗證 JSON 格式**

```bash
echo '{"session_id": "test-session-abc123"}' | bash hooks-handlers/session-start.sh | python3 -m json.tool > /dev/null && echo "Valid JSON"
```

Expected: `Valid JSON`

- [ ] **Step 5：驗證首次執行建立儲存目錄**

```bash
TEST_DIR=$(mktemp -d)
LOGIC_LOG_DIR="$TEST_DIR" bash -c 'echo "{\"session_id\": \"test-abc123\"}" | bash hooks-handlers/session-start.sh > /dev/null'
find "$TEST_DIR" -type f | sort
```

Expected：
```
$TEST_DIR/index.md
$TEST_DIR/theories.md
$TEST_DIR/sessions/test-abc123.md
```

- [ ] **Step 6：驗證 index.md 初始內容**

```bash
TEST_DIR=$(mktemp -d)
LOGIC_LOG_DIR="$TEST_DIR" bash -c 'echo "{\"session_id\": \"test\"}" | bash hooks-handlers/session-start.sh > /dev/null'
cat "$TEST_DIR/index.md"
```

Expected：
```
# Logic Log Index
<!-- 格式：#NNN | ... -->
```

- [ ] **Step 7：Commit**

```bash
git add hooks-handlers/session-start.sh
git commit -m "feat: add session-start.sh - storage init and context injection"
```

---

## Task 3：SKILL.md（Claude 記錄行為定義）

**Files:**
- Create: `skills/logic-log/SKILL.md`

SKILL.md 是 plugin 的核心，定義 Claude 何時輸出記錄、用什麼格式、如何儲存。

- [ ] **Step 1：建立 SKILL.md**

建立 `skills/logic-log/SKILL.md`：

````markdown
---
name: logic-log
description: 在對話中出現分析推理、多維度考量、決策過程、或自我質疑修正時，自動捕捉並結構化記錄，識別背後理論原理。有分析就記。
---

# Logic Log

## When to Use

以下情境必須在回應末尾輸出邏輯記錄區塊（**不中斷主要回答，加在最後**）：

| 情境 | 例子 |
|------|------|
| 發現現有方法的問題 | 「這樣做不對，因為...」 |
| 說明為什麼 A 比 B 好 | 「我選這個是因為...」 |
| 列舉多個考量維度 | 「我考慮了成本、風險、擴展性...」 |
| 自我質疑後修正 | 「等等，這樣其實也有問題...」 |
| 使用者的直覺判斷 | 即使未解釋，Claude 識別背後理論後記錄 |
| Claude 提出有論證的方案 | 附「為什麼適合你需求」的論證 |
| 方向性決策確認 | 確認某個技術、策略或架構選擇 |

## Record Types

**SESSION**：與當前任務直接綁定的決策推理。換個任務就不適用。
**INSIGHT**：跨任務可複用的思維框架或原則。放到任何類似情境都成立。

同一段對話可同時觸發兩筆——一筆 SESSION（這次的決策），一筆 INSIGHT（提煉出的原則）。

## Output Format

```
┌─ [SESSION] 邏輯記錄 #003 ─────────────────────────────────┐
│ 📌 主題：為什麼不用行數估工時                               │
│                                                            │
│ ❓ 問題/動機                                               │
│   v2 用行數對照工時，但腦力工作行數少不代表工時少            │
│                                                            │
│ 🧠 直覺與推理（保留使用者原話或原意）                       │
│   「行數多通常確實費時，但行數少不代表簡單」                 │
│                                                            │
│ 🔍 考量維度                                                │
│   · 行數 vs 腦力投入的相關性                                │
│   · 機械式變動 vs 人工 code                                 │
│   · 系統性偏差 vs 隨機誤差                                  │
│                                                            │
│ ❌ 排除項目（為什麼）                                       │
│   改用 modules 數 → 同樣是規則式判斷，本質相同              │
│                                                            │
│ ✅ 結論                                                    │
│   行數只作為正向信號，最終靠語意判斷                         │
│                                                            │
│ 📚 背後理論（Claude 識別）                                  │
│   · 代理變數謬誤：用易量化指標替代真實目標，相關 ≠ 因果     │
│   · 大數法則：大樣本隨機誤差收斂，系統性偏差不會            │
│                                                            │
│ 🔗 supersedes #001                                         │
│ 📁 2026-05-15 14:23                                        │
└────────────────────────────────────────────────────────────┘
```

### 欄位規則

| 欄位 | 必填 | 說明 |
|------|------|------|
| 類型標籤 | ✅ | `[SESSION]` 或 `[INSIGHT]` |
| 📌 主題 | ✅ | 一句話描述核心問題 |
| ❓ 問題/動機 | ✅ | 什麼情況觸發了這個分析？ |
| 🧠 直覺與推理 | ✅ | 保留使用者原話或原意，不過度改寫 |
| 🔍 考量維度 | ✅ | 至少 2 個面向 |
| ❌ 排除項目 | 選填 | 有排除方案時才填 |
| ✅ 結論 | ✅ | 最終判斷或選擇 |
| 📚 背後理論 | ✅ | 見「Theory Identification」 |
| 🔗 關聯 | 選填 | 有關聯記錄時填 |
| 📁 時間戳 | ✅ | `YYYY-MM-DD HH:MM` |

## Numbering

使用 SessionStart hook 注入的起始編號，session 內自行遞增：

- Context 中若有「下一筆記錄從 #NNN 開始」→ 從 NNN 開始，每筆 +1
- 若無此注入 → 從 #001 開始

編號格式：三位數補零（#001、#042、#123）。

## Theory Identification

**開放式識別，不限學科，不限清單。**

使用者不需要知道理論名稱。Claude 用自身知識庫辨識推理背後的理論或原則：

- 找到正式理論 → 理論名稱 + 一句說明「如何解釋此推理」
- 有原則但無正式名稱 → 一句話描述這個原則
- 完全找不到對應 → 寫「暫無對應理論」，不強行套用

範圍示例（非完整清單）：奧卡姆剃刀、YAGNI、大數法則、中心極限定理、代理變數謬誤、單一職責、機會成本、確認偏誤、第一性原理、熵增定律……

## Relation Chain

| 關係 | 意義 |
|------|------|
| `supersedes #N` | 這筆更新或推翻了 #N 的結論 |
| `refines #N` | 這筆深化或補充了 #N 的分析 |
| `extends #N` | 在 #N 同一框架下新增面向 |

## Storage

輸出記錄區塊後，立即用 Write 工具儲存到三個位置。

**取得儲存路徑：**
```bash
LOG_DIR="${LOGIC_LOG_DIR:-$HOME/.claude/logic-logs}"
```

### 1. Session 完整記錄

檔案：`$LOG_DIR/sessions/{claude-session-id}.md`
操作：append 完整記錄區塊到 session 檔案末尾。

### 2. 摘要索引（index.md）

檔案：`$LOG_DIR/index.md`
操作：append 一行：

```
#NNN | YYYY-MM-DD HH:MM | {claude-session-id} | {session-start-timestamp} | TYPE | 主題 | 理論1·理論2
```

其中 `claude-session-id` 和 `session-start-timestamp` 從 SessionStart hook 注入的 context 中取得。

### 3. Theory Ledger（theories.md）

檔案：`$LOG_DIR/theories.md`
操作：對每個識別到的理論：

**找到對應條目** → 在該條目的「應用記錄」區塊 append 一行：
```
- #NNN | TYPE | {project} | {claude-session-id} | {session-start-timestamp} | Session大主題 | 當筆主題 | 2-3句說明此理論如何被應用及產生的洞見
```

**找不到對應條目** → append 新條目：
```markdown
## 理論名稱（英文名）
核心：3-4 句通用說明（不含特定案例細節）。
      說明此理論的核心概念、適用範圍、常見誤區。

應用記錄：
- #NNN | TYPE | {project} | {claude-session-id} | {session-start-timestamp} | Session大主題 | 當筆主題 | 描述
```

**Session 大主題：** Claude 根據當前對話脈絡判斷，就地記錄，不回頭更新之前的記錄。
````

- [ ] **Step 2：驗證 SKILL.md frontmatter**

```bash
head -5 skills/logic-log/SKILL.md
```

Expected：
```
---
name: logic-log
description: 在對話中出現分析推理...
---
```

- [ ] **Step 3：Commit**

```bash
git add skills/logic-log/SKILL.md
git commit -m "feat: add logic-log SKILL.md - core Claude recording behavior"
```

---

## Task 4：statusline.sh（狀態列顯示）

**Files:**
- Create: `hooks-handlers/statusline.sh`

> **前置確認：** Claude Code 是否支援 Statusline hook 事件。若不支援，此腳本仍可實作，hook 宣告留待後續補上。

- [ ] **Step 1：建立 statusline.sh**

建立 `hooks-handlers/statusline.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="${LOGIC_LOG_DIR:-$HOME/.claude/logic-logs}"
INDEX_FILE="$LOG_DIR/index.md"

# 若無 index 檔或無記錄，不顯示
if [ ! -f "$INDEX_FILE" ]; then
    exit 0
fi

# 取得最近 3 筆
RECENT=$(grep -P '^#\d+' "$INDEX_FILE" 2>/dev/null | tail -3 || echo "")

if [ -z "$RECENT" ]; then
    exit 0
fi

# 格式化：#NNN 主題｜理論
FORMAT_LINE() {
    local line="$1"
    local num type topic theories
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
STATUS="${STATUS% ·}"

echo "$STATUS"
exit 0
```

- [ ] **Step 2：設定執行權限**

```bash
chmod +x hooks-handlers/statusline.sh
```

- [ ] **Step 3：測試（模擬有記錄的狀況）**

```bash
TEST_DIR=$(mktemp -d)
cat > "$TEST_DIR/index.md" << 'EOF'
# Logic Log Index
#001 | 2026-05-15 14:23 | abc123 | 2026-05-15-14-23 | SESSION | 為什麼不用行數估工時 | 代理變數謬誤·大數法則
#002 | 2026-05-15 15:01 | abc123 | 2026-05-15-14-23 | INSIGHT | 直覺與理論的橋接 | 奧卡姆剃刀
#003 | 2026-05-15 16:00 | def456 | 2026-05-15-16-00 | SESSION | Skill+Hook 架構選型 | YAGNI
EOF
LOGIC_LOG_DIR="$TEST_DIR" bash hooks-handlers/statusline.sh
```

Expected（類似）：
```
💡 #001 為什麼不用行數估工時｜代理變數謬誤·大數法則  · #002 直覺與理論的橋接｜奧卡姆剃刀  · #003 Skill+Hook 架構選型｜YAGNI
```

- [ ] **Step 4：測試（無記錄時靜默退出）**

```bash
TEST_DIR=$(mktemp -d)
LOGIC_LOG_DIR="$TEST_DIR" bash hooks-handlers/statusline.sh
echo "exit code: $?"
```

Expected：無輸出，exit code: 0

- [ ] **Step 5：Commit**

```bash
git add hooks-handlers/statusline.sh
git commit -m "feat: add statusline.sh - display recent 3 logic records"
```

---

## Task 5：/llog 指令（llog.md）

**Files:**
- Create: `commands/llog.md`

- [ ] **Step 1：建立 llog.md**

建立 `commands/llog.md`：

````markdown
---
description: "查詢、搜尋、分享 logic-log 邏輯記錄"
argument-hint: "[編號 | today | share | search <關鍵字> | #NNN | ref #NNN]"
allowed-tools: ["Read", "Bash", "Write"]
---

# /llog 指令

查詢與管理 logic-log 邏輯記錄。

**儲存路徑：** `${LOGIC_LOG_DIR:-$HOME/.claude/logic-logs}/`

**使用者指令：** "$ARGUMENTS"

## 子命令對照

根據 `$ARGUMENTS` 執行對應動作：

### 無參數：`/llog`
列出本次 session 的所有記錄摘要。

直接讀取 `sessions/{current-session-id}.md`，列出每筆記錄的主題與時間：
```
#001 [SESSION] 14:23 — 為什麼不用行數估工時
#002 [INSIGHT] 15:01 — 直覺與理論的橋接
```

### 數字：`/llog 3`
顯示本 session 第 3 筆記錄的完整內容。

讀取 `sessions/{current-session-id}.md`，取出第 3 個記錄區塊。

### today：`/llog today`
顯示今日所有記錄摘要。

grep `index.md` 找今天日期的所有行，取出對應的 session ID 和編號，讀取對應 session 檔。

### share：`/llog share`
輸出可直接複製分享的乾淨格式（移除邊框字元，保留結構）。

### search：`/llog search <關鍵字>`
跨所有記錄搜尋。

```bash
grep -r "<關鍵字>" "${LOGIC_LOG_DIR:-$HOME/.claude/logic-logs}/sessions/" --include="*.md" -l
```

列出命中的檔案與相關段落。

### 全局編號：`/llog #042`
直接開啟第 042 筆記錄的完整內容，不限 session。

從 `index.md` 找到 #042 的 session ID，讀取 `sessions/{session-id}.md` 取出對應區塊。

### ref：`/llog ref #042`
把 #042 的邏輯注入當前對話 context，讓後續推理可直接引用。

從 `index.md` 找到 #042 的 session ID，讀取完整內容，在對話中顯示並說明：「已載入 #042 的邏輯，後續推理可直接引用此分析。」
````

- [ ] **Step 2：驗證 frontmatter**

```bash
head -6 commands/llog.md
```

Expected：
```
---
description: "查詢、搜尋、分享 logic-log 邏輯記錄"
argument-hint: "[編號 | today | share | search <關鍵字> | #NNN | ref #NNN]"
allowed-tools: ["Read", "Bash", "Write"]
---
```

- [ ] **Step 3：Commit**

```bash
git add commands/llog.md
git commit -m "feat: add /llog command definition"
```

---

## Task 6：README.md（安裝說明）

**Files:**
- Create: `README.md`

- [ ] **Step 1：建立 README.md**

建立 `README.md`：

````markdown
# logic-log

Claude Code plugin，自動捕捉對話中的邏輯思維與決策過程。

**核心理念：你的直覺是主角，Claude 是結構化記錄員——把你的直覺接上理論名稱，變成可引用的知識資產。**

## 記錄類型

- **SESSION**：任務脈絡型，與當前任務直接綁定
- **INSIGHT**：知識資產型，跨任務可複用的思維框架

每筆記錄包含：問題/動機、直覺與推理、考量維度、排除項目、結論、以及 Claude 識別的背後理論。

## 前置需求

- Claude Code
- `jq`（JSON 解析）：`brew install jq` / `apt install jq`
- `bash` 4.0+
- `git`（取得 project 名稱，可選）

## 安裝

### 方法一：從 Plugin Marketplace 安裝

```bash
/plugins install logic-log
```

### 方法二：手動安裝

1. Clone 此 repo：
```bash
git clone https://github.com/glenncheng/logic-log ~/.claude/plugins/local/logic-log
```

2. 在 Claude Code 中安裝：
```bash
/plugins install ~/.claude/plugins/local/logic-log
```

## 使用

安裝後，每次 Claude Code session 自動啟用。當對話出現分析推理、決策或多維度考量時，Claude 會在回應末尾輸出邏輯記錄區塊並自動存檔。

### /llog 指令

| 指令 | 效果 |
|------|------|
| `/llog` | 本次 session 所有記錄摘要 |
| `/llog 3` | 本 session 第 3 筆完整內容 |
| `/llog today` | 今日所有記錄 |
| `/llog share` | 輸出可分享的乾淨格式 |
| `/llog search <關鍵字>` | 跨所有 session 搜尋 |
| `/llog #042` | 開啟第 042 筆（不限 session） |
| `/llog ref #042` | 把 #042 的邏輯注入當前對話 |

### 儲存位置

記錄存在 `~/.claude/logic-logs/`（可用 `LOGIC_LOG_DIR` 環境變數自訂路徑）：

```
~/.claude/logic-logs/
├── sessions/
│   └── {claude-session-id}.md    ← 每個 session 一個檔
├── index.md                       ← 全局摘要索引
└── theories.md                    ← 理論圖鑑（以理論為出發點的反向索引）
```

## 自訂儲存路徑

在 shell 設定（`.bashrc` / `.zshrc`）加入：

```bash
export LOGIC_LOG_DIR="$HOME/Documents/logic-logs"
```

## Theory Ledger

`theories.md` 是反向索引：以理論為出發點，記錄每個理論的核心說明以及你曾在哪些任務中用過它。隨時間累積後，可以看出自己的思維傾向與知識脈絡。
````

- [ ] **Step 2：Commit**

```bash
git add README.md
git commit -m "docs: add README with installation and usage instructions"
```

---

## Task 7：整合驗證

- [ ] **Step 1：驗證完整目錄結構**

```bash
find . -not -path './.git/*' -not -path './docs/*' -type f | sort
```

Expected：
```
./.claude-plugin/plugin.json
./commands/llog.md
./hooks-handlers/session-start.sh
./hooks-handlers/statusline.sh
./hooks/hooks.json
./README.md
./skills/logic-log/SKILL.md
```

- [ ] **Step 2：驗證 session-start.sh 完整 context 注入**

```bash
echo '{"session_id": "integration-test-123"}' | bash hooks-handlers/session-start.sh | jq '.hookSpecificOutput.additionalContext'
```

Expected：字串中包含：
- `Logic Log Session Context`
- `Claude Session ID`
- `下一筆記錄從 #001 開始`
- `最近 5 筆記錄`

- [ ] **Step 3：驗證第二次執行時編號遞增**

```bash
TEST_DIR=$(mktemp -d)

# 模擬已有 3 筆記錄
cat > "$TEST_DIR/index.md" << 'EOF'
# Logic Log Index
#001 | 2026-05-15 14:00 | abc | 2026-05-15-14-00 | SESSION | 測試記錄一 | 奧卡姆剃刀
#002 | 2026-05-15 14:30 | abc | 2026-05-15-14-00 | INSIGHT | 測試記錄二 | YAGNI
#003 | 2026-05-15 15:00 | abc | 2026-05-15-14-00 | SESSION | 測試記錄三 | 大數法則
EOF

LOGIC_LOG_DIR="$TEST_DIR" bash -c 'echo "{\"session_id\": \"new-session\"}" | bash hooks-handlers/session-start.sh' | jq '.hookSpecificOutput.additionalContext' | grep -o '下一筆記錄從 #[0-9]*'
```

Expected：`下一筆記錄從 #004`

- [ ] **Step 4：Final commit**

```bash
git add -A
git status  # 確認無多餘檔案
git commit -m "feat: logic-log plugin v1.0.0 - complete implementation" --allow-empty-message || true
```

若無新檔案則跳過此步。

---

## 設計備忘

| 項目 | 說明 |
|------|------|
| Statusline hook | Claude Code 是否支援待確認，statusline.sh 已實作，hook 宣告留待補上 |
| Session ID 格式 | 從 hook stdin JSON 的 `.session_id` 讀取（Claude Code 原生提供） |
| 路徑可配置 | `LOGIC_LOG_DIR` 環境變數，預設 `~/.claude/logic-logs/` |
| 初始化時機 | session-start.sh 每次執行時做 `mkdir -p` 和 `[ ! -f ]` 檢查，冪等 |
| 理論識別 | 開放式，SKILL.md 說明範圍但不限清單，Claude 自行判斷 |
| 重要性機制 | 關聯鏈（supersedes/refines/extends），重要性由存活率自然顯現 |
