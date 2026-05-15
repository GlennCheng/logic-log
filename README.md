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
