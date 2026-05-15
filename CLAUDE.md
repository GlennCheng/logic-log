# Logic Log Plugin

## 這個專案是什麼

一個 Claude Code plugin，用於自動捕捉並結構化對話中的邏輯思維與決策過程。

**核心定位：使用者的邏輯思維是主角，Claude 是結構化記錄員。**

使用者（Glenn）發現自己的分析推理能力很強——常常考量的維度比別人多、背後有理論支撐——但這些思路都散落在對話裡消失了。這個 plugin 讓這些邏輯變成可保存、可分享、可跨 session 引用的知識資產。

---

## 目前狀態

- [x] 需求釐清完成
- [x] 設計文件完成（`docs/superpowers/specs/2026-05-15-logic-log-design.md`）
- [ ] 實作規劃（下一步）
- [ ] Plugin 實作

---

## 設計決策摘要

| 決策 | 選擇 | 理由 |
|------|------|------|
| 架構 | Skill + Hook Plugin | 比純 Skill 可靠（Hook 自動觸發），比 MCP 輕量（零外部依賴） |
| 儲存格式 | Markdown | 零依賴、人類可讀、可直接分享 |
| Plugin 名稱 | `logic-log` | 直接對應「邏輯」，比 reasoning/logical 更直覺 |
| 指令名稱 | `/llog` | 簡短、對應 plugin 名稱 |
| 搜尋 | grep/ripgrep | 無需資料庫 |

---

## Plugin 完整規格

### 檔案結構

```
logic-log/
├── .claude-plugin/
│   └── plugin.json
├── hooks/
│   └── hooks.json           ← SessionStart + Statusline
├── hooks-handlers/
│   ├── session-start.sh     ← 載入最近 5 筆記錄到 session context
│   └── statusline.sh        ← 狀態列顯示最近 3 筆（主題+考量+結論）
├── skills/
│   └── logic-log/
│       └── SKILL.md         ← 告訴 Claude 何時輸出、用什麼格式
├── commands/
│   └── llog.md              ← /llog 指令定義
└── README.md
```

### 記錄格式

```
┌─ 邏輯記錄 #003 ─────────────────────────────────────┐
│ 📌 主題：...                                          │
│ 🧠 核心邏輯（使用者的分析）                           │
│ 🔍 考量維度                                           │
│ ❌ 排除項目（為什麼）                                  │
│ ✅ 結論優勢                                           │
│ 📚 理論依據（Claude 識別對應理論/原則）                │
│ 📁 YYYY-MM-DD HH:MM                                  │
└───────────────────────────────────────────────────────┘
```

### 觸發條件

- 使用者提出分析框架
- 使用者說明為什麼某方案更好
- 使用者列舉多維度考量
- 使用者做出方向性決定
- Claude 提出解決方案（附論證）

### 儲存路徑

```
~/.claude/logic-logs/
├── YYYY-MM-DD.md    ← 當日完整記錄
├── index.md         ← 所有記錄摘要索引
└── export/          ← 乾淨版，可直接分享
```

### /llog 指令（Claude Code 中使用）

| 指令 | 效果 |
|------|------|
| `/llog` | 本次 session 摘要列表 |
| `/llog 3` | 本 session 第 3 筆完整內容 |
| `/llog today` | 今日所有記錄 |
| `/llog share` | 輸出乾淨格式可分享 |
| `/llog search <關鍵字>` | 跨所有 session 搜尋 |
| `/llog #042` | 開啟第 042 筆（不限 session） |
| `/llog ref #042` | 把 #042 邏輯注入當前對話 context |

### SessionStart Hook

每次開啟 session，自動把最近 5 筆記錄摘要注入給 Claude，讓後續對話可直接引用過去的邏輯。

### 狀態列格式

```
💡 #003 主題｜考量1·考量2｜結論  ·  #002 ...  ·  #001 ...
```

---

## 下一步：實作順序（建議）

1. **SKILL.md** — 核心行為定義，先把觸發條件和記錄格式寫清楚
2. **session-start.sh** — SessionStart hook，載入過去記錄
3. **statusline.sh** — 狀態列顯示
4. **plugin.json + hooks.json** — Plugin 元數據和 hook 宣告
5. **llog.md** — `/llog` 指令各子命令的實作
6. **README.md** — 安裝說明

---

## 參考資料

- 設計文件：`docs/superpowers/specs/2026-05-15-logic-log-design.md`
- 參考 plugin 範例：`~/.claude/plugins/marketplaces/claude-plugins-official/plugins/learning-output-style/`
- Skill 格式參考：`~/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0/skills/systematic-debugging/SKILL.md`
