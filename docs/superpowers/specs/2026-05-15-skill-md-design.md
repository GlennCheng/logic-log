# Logic Log SKILL.md 設計文件

**日期：** 2026-05-15
**狀態：** 待實作
**關聯：** `2026-05-15-logic-log-design.md`（整體 plugin 設計）

---

## 一、SKILL.md 的職責

SKILL.md 是 logic-log plugin 的核心行為定義，告訴 Claude：
- **何時**輸出邏輯記錄區塊
- **用什麼格式**輸出
- **如何判斷**記錄類型與背後理論
- **如何儲存**到對應檔案

---

## 二、記錄類型

兩種類型，共用同一格式，以標頭標籤區分：

| 類型 | 定義 | 判斷標準 |
|------|------|---------|
| `SESSION` | 任務脈絡型——與當前任務直接綁定的決策推理 | 換個任務就不適用 |
| `INSIGHT` | 知識資產型——跨任務可複用的思維框架或原則 | 放到任何類似情境都成立 |

同一段對話可以同時觸發兩筆——一筆 SESSION（這次的決策），一筆 INSIGHT（提煉出的原則）。

---

## 三、觸發條件（寬鬆）

以下情境發生時，Claude 必須輸出邏輯記錄區塊：

| 情境 | 例子 |
|------|------|
| 發現現有方法的問題 | 「這樣做不對，因為...」 |
| 說明為什麼 A 比 B 好 | 「我選這個是因為...」 |
| 列舉多個考量維度 | 「我考慮了成本、風險、擴展性...」 |
| 自我質疑後修正 | 「等等，這樣其實也有問題...」 |
| 直覺性判斷（即使沒解釋） | Claude 識別直覺背後的理論後記錄 |
| Claude 提出有論證的方案 | 附上「為什麼適合你需求」的論證 |
| 方向性決策確認 | 確認某個技術、策略或架構選擇 |

---

## 四、記錄格式

記錄區塊輸出在**回應末尾**，不干擾主要回答。

```
┌─ [SESSION] 邏輯記錄 #003 ────────────────────────────────┐
│ 📌 主題：為什麼不用行數估工時                              │
│                                                           │
│ ❓ 問題/動機                                              │
│   v2 用行數對照工時，但 1 行 race condition 可能花 3 天    │
│                                                           │
│ 🧠 直覺與推理（保留使用者原話或原意）                      │
│   「行數多通常確實費時，但行數少不代表簡單」               │
│                                                           │
│ 🔍 考量維度                                               │
│   · 行數 vs 腦力投入的相關性                               │
│   · 機械式變動 vs 人工 code                                │
│   · 系統性偏差 vs 隨機誤差                                 │
│                                                           │
│ ❌ 排除項目（為什麼）                                      │
│   改用 modules 數 → 同樣是規則式判斷，本質相同             │
│                                                           │
│ ✅ 結論                                                   │
│   行數只作為正向信號，最終靠 LLM 語意判斷                  │
│                                                           │
│ 📚 背後理論（Claude 識別）                                 │
│   · 代理變數謬誤：用易量化指標替代真實目標，相關 ≠ 因果    │
│   · 大數法則：大樣本隨機誤差收斂，系統性偏差不會           │
│                                                           │
│ 🔗 supersedes #001                                        │
│ 📁 2026-05-15 14:23                                       │
└───────────────────────────────────────────────────────────┘
```

### 欄位說明

| 欄位 | 必填 | 說明 |
|------|------|------|
| 類型標籤 | ✅ | `[SESSION]` 或 `[INSIGHT]` |
| 📌 主題 | ✅ | 一句話描述這筆記錄的核心問題 |
| ❓ 問題/動機 | ✅ | 什麼情況觸發了這個分析？發現了什麼問題？ |
| 🧠 直覺與推理 | ✅ | 保留使用者原話或原意，不過度改寫 |
| 🔍 考量維度 | ✅ | 分析時考量了哪些面向（至少 2 個） |
| ❌ 排除項目 | 選填 | 哪些方案被排除，具體原因 |
| ✅ 結論 | ✅ | 最終判斷或選擇 |
| 📚 背後理論 | ✅ | Claude 識別的理論或原則（見第五節） |
| 🔗 關聯 | 選填 | 與其他記錄的關係（見第六節） |
| 📁 時間戳 | ✅ | `YYYY-MM-DD HH:MM` |

---

## 五、理論識別

### 原則

Claude 用自身知識庫辨識使用者推理背後對應的理論、原則或定律，**開放式，不限學科，不限清單**。使用者不需要知道理論名稱——Claude 的工作是「把直覺接上名字」。

識別範圍示例（非完整清單）：

| 學科類別 | 常見理論 |
|---------|---------|
| 邏輯 / 決策 | 奧卡姆剃刀、YAGNI、機會成本、風險收益矩陣、第一性原理 |
| 統計 / 數學 | 大數法則、中心極限定理、1/√N 收斂、系統性偏差 vs 隨機誤差 |
| 工程原則 | 單一職責、關注點分離、代理變數謬誤、SOLID |
| 認知 / 心理 | 確認偏誤、錨定效應、沉沒成本謬誤 |
| 物理 / 科學方法 | 熱力學熵增、收斂性、假說驗證 |

### 識別規則

- 找到對應的正式理論 → 寫理論名稱 + 一句說明它如何解釋這個推理
- 有原則但無正式名稱 → 用一句話描述這個原則
- 完全找不到對應 → 寫「暫無對應理論」，不強行套用

---

## 六、關聯鏈（Relation Chain）

記錄之間可聲明關係，讓重要性透過「存活率」自然顯現：

| 關係 | 意義 |
|------|------|
| `supersedes #N` | 這筆更新或推翻了 #N 的結論 |
| `refines #N` | 這筆深化或補充了 #N 的分析 |
| `extends #N` | 在 #N 的同一框架下新增面向 |

被 `supersedes` 的記錄在 `/llog` 列表時標注 `[已超越]`，但原始內容保留（append-only）。

---

## 七、Theory Ledger（理論圖鑑）

### 定位

Theory Ledger 是**反向索引**：
- 記錄（SESSION/INSIGHT）= 正向索引（這筆邏輯 → 用了哪些理論）
- Theory Ledger = 反向索引（這個理論 → 在哪些地方被用到）

比喻：SESSION/INSIGHT 是論文正文，Theory Ledger 是論文末尾的**主題索引**。或者：SESSION/INSIGHT 是任務日誌與攻略心得，Theory Ledger 是**技能圖鑑**（每個技能的說明 + 在哪些關卡用過）。

### 儲存位置

`~/.claude/logic-logs/theories.md`

### 格式

```markdown
## 大數法則（Law of Large Numbers）
核心：樣本越大，隨機誤差以 1/√N 速度收斂，整體估算趨於穩定。
      但系統性偏差（如對某類任務一致性錯估）不會因樣本大而消失，
      大樣本只能抵銷隨機誤差，無法救系統性錯誤。
      例如：分母樣本大（數千筆）可容忍個別估算噪音；
      分子樣本小（數十筆）則每筆誤差都直接影響最終比例。

應用記錄：
- #003 | SESSION | project-magento2-hotai | a1b2c3d4-e5f6 | 2026-05-15-14-23 | 驗收款項扣減計算 v3 | 分子 vs 分母噪音不對等 | 未完成票（小樣本）每筆估算誤差直接影響扣款率，已完成票（大樣本）隨機誤差統計上互相抵銷，因此應採不同處理策略：小樣本逐筆深度審查，大樣本走批次平行處理

---
## 奧卡姆剃刀（Occam's Razor）
核心：在滿足需求的前提下，選擇最簡單的方案。
      不為假設的未來需求增加複雜度，每增加一層複雜度都需要明確的理由，
      否則維護成本與出錯機率都會無謂上升。

應用記錄：
- #001 | SESSION | logic-log | f6e5d4c3-b2a1 | 2026-05-15-16-01 | logic-log plugin 架構選型 | 選 Skill+Hook 而非 MCP | MCP 引入外部服務依賴，但需求只是輕量記錄；Skill+Hook 零依賴且自動觸發，滿足 80% 功能但成本趨近於零
```

### 應用記錄欄位

`#編號 | 類型 | 專案 | Claude Session ID | Session 開始時間戳 | Session 大主題 | 當筆主題 | 簡單描述`

| 欄位 | 來源 |
|------|------|
| #編號 | 記錄的全局編號 |
| 類型 | SESSION 或 INSIGHT |
| 專案 | session-start.sh 從 git repo 名稱或工作目錄自動抓取 |
| Claude Session ID | Claude Code 原生 session ID（從 hook stdin `.session_id` 讀取） |
| Session 開始時間戳 | 格式 `YYYY-MM-DD-HH-MM`，session 開始時由 session-start.sh 產生並注入 |
| Session 大主題 | Claude 在寫記錄當下，根據對話脈絡判斷目前在做什麼，就地記錄，**不回頭更新之前的記錄** |
| 當筆主題 | 這筆記錄的具體主題 |
| 簡單描述 | 2-3 句說明此理論如何被應用、產生什麼洞見 |

範例：
```
- #003 | SESSION | project-magento2-hotai | a1b2c3d4-e5f6 | 2026-05-15-14-23 | 驗收款項扣減計算 v3 | 分子 vs 分母噪音不對等 | 未完成票（小樣本）每筆估算誤差直接影響扣款率，已完成票（大樣本）隨機誤差統計上互相抵銷，應採不同處理策略
```

### 更新規則

每次 Claude 寫一筆記錄並識別到理論時：
1. 在 theories.md 找該理論條目
2. 找到 → 在「應用記錄」下新增一行
3. 找不到 → 新建條目（核心說明 + 第一筆應用記錄）

---

## 八、儲存機制

### 儲存位置

```
~/.claude/logic-logs/
├── sessions/
│   ├── {claude-session-id}.md    ← 每個 session 一個檔（主要存取單位）
│   └── {claude-session-id}.md
├── index.md                       ← 全局摘要索引（含日期，供跨日查詢與搜尋）
└── theories.md                    ← Theory Ledger（理論圖鑑）
```

**每個 session 獨立一個檔案**，以 Claude 原生 session ID 命名。主要查詢（`/llog`、`/llog 3`）直接讀當前 session 檔，無需 grep。跨日/全局查詢走 index.md。

### index.md 格式

每筆記錄一行，**七個欄位**：

```
#NNN | YYYY-MM-DD HH:MM | {claude-session-id} | YYYY-MM-DD-HH-MM | TYPE | 主題 | 理論1·理論2
```

| 欄位 | 說明 |
|------|------|
| #NNN | 全局編號（三位數補零） |
| YYYY-MM-DD HH:MM | 記錄寫入時間 |
| {claude-session-id} | Claude Code 原生 session ID（從 hook stdin `.session_id` 讀取） |
| YYYY-MM-DD-HH-MM | Session 開始的日期 + 時分（human-readable 時間戳） |
| TYPE | SESSION 或 INSIGHT |
| 主題 | 記錄的核心問題 |
| 理論 | 識別到的理論，多個用 `·` 分隔 |

範例：
```
#003 | 2026-05-15 14:23 | a1b2c3d4-e5f6 | 2026-05-15-14-23 | SESSION | 為什麼不用行數估工時 | 代理變數謬誤·大數法則
```

### 儲存流程

Claude 輸出記錄區塊後，自動執行：

1. 完整記錄 → append 到 `~/.claude/logic-logs/sessions/{claude-session-id}.md`
2. 摘要索引 → 在 `~/.claude/logic-logs/index.md` append 一行（七欄格式）
3. 理論更新 → 在 `~/.claude/logic-logs/theories.md` 對應條目新增應用記錄

### 查詢對應

| 查詢 | 實作 |
|------|------|
| `/llog`（本 session） | 直接讀 `sessions/{current-session-id}.md` |
| `/llog 3`（本 session 第 3 筆） | 讀同一 session 檔，取第 3 個記錄區塊 |
| `/llog today` | grep index.md 找今天日期，讀對應 session 檔 |
| `/llog #042` | grep index.md 找 #042 的 session ID，讀對應 session 檔 |
| `/llog search <關鍵字>` | grep 所有 `sessions/*.md` |

### 編號機制

- SessionStart hook 讀取 `index.md` 最新編號，注入 context（「下一筆記錄從 #008 開始」）
- Session 內 Claude 自行遞增，不需每次讀檔

---

## 九、SKILL.md 結構概覽

實際 SKILL.md 檔案將包含：

1. **Frontmatter**：name + description（觸發時機描述）
2. **When to Use**：觸發條件列表
3. **Record Types**：SESSION vs INSIGHT 判斷規則
4. **Output Format**：完整記錄格式範例
5. **Theory Identification**：開放式識別規則
6. **Relation Chain**：supersedes / refines / extends
7. **Theory Ledger**：theories.md 更新規則
8. **Storage Instructions**：三個檔案的寫入步驟
9. **Numbering**：使用 session 注入的起始編號

---

## 十、設計決策摘要

| 決策 | 選擇 | 理由 |
|------|------|------|
| 輸出時機 | 回應末尾 | 閱讀流最自然，不干擾主要回答 |
| 觸發頻率 | 寬鬆（有分析就記） | 不漏掉任何直覺推理 |
| 類型 | SESSION / INSIGHT 二分 | 任務脈絡 vs 跨任務知識資產，用途不同 |
| 重要性標記 | 關聯鏈（supersedes/refines） | 重要性透過存活率自然顯現，不主觀評分 |
| 理論識別 | Claude 開放式識別 | 使用者的直覺 → Claude 接上理論名稱 |
| Theory Ledger | 獨立 theories.md 反向索引 | 以理論為出發點查應用記錄，互補正向索引 |
| 儲存格式 | Markdown | 零依賴、人類可讀、可直接分享 |
| 編號 | SessionStart 注入起始值 | 跨 session 連續，不需每次讀檔 |
| Session 檔案命名 | {claude-session-id}.md | 主要查詢直接讀檔，不需 grep |
| 跨日查詢 | grep index.md 日期欄位 | index.md 是全局索引，含日期可過濾 |
| Session ID 欄位 | 兩欄分開 | Claude 原生 ID（檔名）+ 日期時分（可讀時間戳）|
