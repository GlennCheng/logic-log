---
description: "查詢、搜尋、分享 logic-log 邏輯記錄"
argument-hint: "[編號 | today | share | search <關鍵字> | #NNN | ref #NNN | recap]"
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

從 SessionStart hook 注入的 context 取得 current-session-id（找「**Claude Session ID：** ...」這行）。

讀取 `sessions/{current-session-id}.jsonl`，每行 parse 一筆 JSON，輸出摘要：

```
#001 [SESSION|USER]  14:23 — 為什麼不用行數估工時
#002 [INSIGHT|JOINT] 15:01 — 直覺與理論的橋接
#003 [SESSION|AI]    15:30 — hooks.json 格式驗證
```

格式：`#{id:03d} [{type}|{source}] {timestamp HH:MM} — {topic}`

### 數字：`/llog 3`
顯示本 session 第 3 筆記錄的完整內容。

讀取 `sessions/{current-session-id}.jsonl`，找 `"id": 3` 的那行，用 Bash 呼叫 render 腳本輸出 box 格式：

```bash
LOG_DIR="${LOGIC_LOG_DIR:-$HOME/.claude/logic-logs}"
SESSION_ID="<current-session-id>"
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/render.py" \
    "$LOG_DIR/sessions/$SESSION_ID.jsonl" 3
```

### today：`/llog today`
顯示今日所有記錄摘要。

```bash
grep "$(date +%Y-%m-%d)" "${LOGIC_LOG_DIR:-$HOME/.claude/logic-logs}/index.md"
```

列出今天的所有 index 行，按時間排序顯示。

### share：`/llog share`
輸出可直接複製分享的乾淨格式。

讀取本 session 的所有 JSONL 記錄，對每筆逐欄輸出純文字（不含框線字元）：

```
[SESSION | USER] #001 — 為什麼不用行數估工時
主題：為什麼不用行數估工時
問題/動機：v2 用行數對照工時...
直覺與推理：...
推理過程：1. ... 2. ...
考量維度：...
結論：...
理論：代理變數謬誤 · 大數法則
────────────────────────────────
```

### search：`/llog search <關鍵字>`
跨所有記錄搜尋。

```bash
grep -r "<關鍵字>" "${LOGIC_LOG_DIR:-$HOME/.claude/logic-logs}/sessions/" \
    --include="*.jsonl" -l
```

在每個命中的 `.jsonl` 中，找包含關鍵字的記錄（parse JSON 後搜尋各欄位），輸出 box 格式並標註來源 session ID。

### 全局編號：`/llog #042`
直接開啟第 042 筆記錄的完整內容，不限 session。

從 `index.md` 找到 `#042` 這行，取得 session ID（第 3 欄），執行：

```bash
LOG_DIR="${LOGIC_LOG_DIR:-$HOME/.claude/logic-logs}"
SESSION_ID="<從 index.md 取得>"
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/render.py" \
    "$LOG_DIR/sessions/$SESSION_ID.jsonl" 42
```

### ref：`/llog ref #042`
把 #042 的邏輯注入當前對話 context，讓後續推理可直接引用。

從 `index.md` 找到 #042 的 session ID，讀取完整 JSON 記錄，在對話中顯示 box 格式並說明：「已載入 #042 的邏輯，後續推理可直接引用此分析。」

### recap：`/llog recap`
回顧當前對話，自動識別所有邏輯推理段落，建立 logic-log 記錄並存檔。

**Step 1：取得 Session ID（Bash 工具）**

優先從對話 context 中找「**Claude Session ID：** ...」，取其後的值。
若找不到，用 Bash 掃描最近修改的 transcript 檔案取得：

```bash
ls -t "$HOME/.claude/projects"/*/*.jsonl 2>/dev/null | head -1
```

取檔名（不含路徑與 `.jsonl` 副檔名）作為 session ID。
兩者都找不到時，fallback 為 `recap-$(date +%Y%m%d-%H%M%S)`。

**Step 2：讀取現有記錄（Bash 工具）**

```bash
LOG_DIR="${LOGIC_LOG_DIR:-$HOME/.claude/logic-logs}"
mkdir -p "$LOG_DIR/sessions"
cat "$LOG_DIR/index.md" 2>/dev/null || echo "（尚無記錄）"
```

取得：
- 目前最大編號（下一筆從 MAX+1 開始）
- 現有記錄的主題與關係（供建立關係鏈參考）

**Step 3：AI 全程分析對話**

目標：**盡可能還原從對話開始到當下的完整推理過程**，不遺漏。
依時間順序從頭掃描對話歷史，識別所有符合觸發條件的推理段落：
- 使用者或 AI 說明為什麼 A 比 B 好
- 列舉多個考量維度做出決策
- 發現問題後修正方向（自我質疑）
- 確認技術、策略或架構選擇
- 識別直覺判斷背後的理論

每個段落獨立評估：
- 定型為 SESSION 或 INSIGHT（或同時兩筆）
- 判斷發起者：**誰先點出問題方向？** → USER / AI / JOINT
  - **USER**：使用者提問、點出直覺或方向，即使 AI 做了所有後續推導；AI 只是協助結構化或分析
  - **AI**：AI 主動識別問題（使用者不知道這個問題存在），或 AI 先提出解法方向
  - **JOINT**：使用者提問方向 + AI 給出使用者想不到的具體設計；有疑問時預設 JOINT
  - 邊界原則：「使用者問 X 是否有問題」→ USER；「AI 發現 X 有問題使用者才知道」→ AI；兩方缺一不可 → JOINT
- 在 🧠 欄位用 `使用者：` / `AI：` 標注各自貢獻；USER 記錄保留使用者原話
- 提煉核心邏輯、推理步驟、考量維度、排除項目、結論
- 識別背後理論（開放式，不限清單）

**Step 4：建立關係鏈**

在所有識別到的記錄之間，以及與 Step 2 讀到的現有記錄之間，找出關係：
- `supersedes #N`：本筆更新或推翻了 #N 的結論
- `refines #N`：本筆深化或補充了 #N 的分析
- `extends #N`：在 #N 同一框架下新增面向

同一次 recap 識別出的多筆記錄之間也可能有關係，用連續編號互相標注。

**Step 5：輸出所有記錄**

依時間順序輸出所有識別到的記錄，使用標準 box 格式（見 SKILL.md Output Format）。
輸出完畢後顯示：「共識別 N 筆記錄，即將存檔。」

**Step 6：存檔（Bash 工具，依序執行）**

```bash
LOG_DIR="${LOGIC_LOG_DIR:-$HOME/.claude/logic-logs}"
SESSION_ID="<Step 1 取得的 ID>"
SESSION_FILE="$LOG_DIR/sessions/$SESSION_ID.jsonl"
INDEX_FILE="$LOG_DIR/index.md"
PROJECT=$(git rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null || basename "$PWD")
mkdir -p "$LOG_DIR/sessions"
```

對每筆記錄，用 Python3 依序執行：

**6a. Append JSON 到 session JSONL：**
```bash
python3 << 'PYEOF'
import json, os
record = {
    "id": NNN,
    "type": "SESSION",
    "source": "USER",
    "topic": "...",
    "timestamp": "YYYY-MM-DD HH:MM",
    "session_id": "SESSION_ID",
    "session_start": "SESSION_START",
    "project": "PROJECT",
    "motivation": "...",
    "reasoning": {"user": "...", "ai": "..."},
    "reasoning_steps": ["...", "..."],
    "dimensions": ["...", "..."],
    "excluded": [],
    "conclusion": "...",
    "assumptions": [],
    "additional": {},
    "theories": ["...", "..."],
    "relations": []
}
path = "SESSION_FILE_PATH"
with open(path, 'a', encoding='utf-8') as f:
    f.write(json.dumps(record, ensure_ascii=False) + '\n')
print(f"✓ {path}")
PYEOF
```

**6b. Append 一行到 index.md：**
```
#NNN | YYYY-MM-DD HH:MM | {session_id} | {session_start} | TYPE:SOURCE | 主題 | 理論1·理論2
```

**6c. 對每個理論更新 theories.md**（邏輯同 SKILL.md Storage 第 3 節）

存檔完成後顯示路徑確認訊息。
