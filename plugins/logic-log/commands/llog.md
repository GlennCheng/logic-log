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

讀取 session 檔的所有記錄區塊（以 `┌─` 開頭、`└─` 結尾），從每個區塊提取 `📌 主題` 欄位與 `📁 時間戳` 欄位，組成摘要列表。

直接讀取 `sessions/{current-session-id}.md`，列出每筆記錄的主題與時間：
```
#001 [SESSION] 14:23 — 為什麼不用行數估工時
#002 [INSIGHT] 15:01 — 直覺與理論的橋接
```

current-session-id 從 SessionStart hook 注入的 context 取得：找「**Claude Session ID：** ...」這行，取其後的值。

### 數字：`/llog 3`
顯示本 session 第 3 筆記錄的完整內容。

讀取 `sessions/{current-session-id}.md`，找所有以 `┌─` 開頭的行作為區塊起點，取第 N 個起點，向下讀至對應的 `└─` 結尾行，輸出完整區塊。

### today：`/llog today`
顯示今日所有記錄摘要。

```bash
grep "$(date +%Y-%m-%d)" "${LOGIC_LOG_DIR:-$HOME/.claude/logic-logs}/index.md"
```

列出今天的所有 index 行，按時間排序顯示。

### share：`/llog share`
輸出可直接複製分享的乾淨格式。

讀取本 session 的所有記錄，移除 `┌─`、`│`、`└─`、`─` 等框線字元，保留 emoji 欄位標記（📌 🧠 🔍 ❌ ✅ 📚 🔗 📁）與純文字內容，逐區塊輸出。

### search：`/llog search <關鍵字>`
跨所有記錄搜尋。

```bash
grep -r "<關鍵字>" "${LOGIC_LOG_DIR:-$HOME/.claude/logic-logs}/sessions/" --include="*.md" -l
```

在每個命中的 `sessions/*.md` 中，找包含關鍵字的完整記錄區塊（從 `┌─` 到 `└─`），輸出該區塊並標註來源 session ID。

### 全局編號：`/llog #042`
直接開啟第 042 筆記錄的完整內容，不限 session。

從 `index.md` 找到 `#042` 這行，取得 session ID（第 3 欄），讀取 `sessions/{session-id}.md` 取出對應記錄區塊。

### ref：`/llog ref #042`
把 #042 的邏輯注入當前對話 context，讓後續推理可直接引用。

從 `index.md` 找到 #042 的 session ID，讀取完整內容，在對話中顯示並說明：「已載入 #042 的邏輯，後續推理可直接引用此分析。」
