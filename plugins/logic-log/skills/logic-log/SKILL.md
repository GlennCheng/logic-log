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
| 使用者的直覺判斷 | 即使未解釋，AI 識別背後理論後記錄 |
| AI 提出有論證的方案 | 附「為什麼適合你需求」的論證 |
| 方向性決策確認 | 確認某個技術、策略或架構選擇 |

### 不記錄的情況

以下情況**不**輸出記錄：
- 純事實問答，沒有推理或決策（「Python 3.12 幾時發布？」）
- 簡短確認或閒聊（「好的」、「了解」、「謝謝」）
- 執行機械式操作，沒有設計判斷（執行已決定好的指令）
- 整個回應只是一句話的答案

## Record Types

**SESSION**：與當前任務直接綁定的決策推理。換個任務就不適用。
**INSIGHT**：跨任務可複用的思維框架或原則。放到任何類似情境都成立。

同一段對話可同時觸發兩筆——一筆 SESSION（這次的決策），一筆 INSIGHT（提煉出的原則）。

### 發起者標籤

每筆記錄必須標注推理的發起來源：

| 標籤 | 意義 |
|------|------|
| `USER` | 推理/決策主要來自使用者（直覺、判斷、選擇） |
| `AI` | 推理/分析主要來自 AI（識別問題、提出方案） |
| `JOINT` | 使用者與 AI 共同推導，缺一不可 |

**判斷原則：誰先點出問題方向？**

| 情境 | 標籤 | 說明 |
|------|------|------|
| 使用者提問 / 點出直覺，AI 做推導 | **USER** | 問題方向來自使用者，AI 只是分析工具 |
| AI 主動發現問題（未受使用者提問觸發） | **AI** | 使用者不知道這個問題存在 |
| 使用者提問方向 + AI 給出使用者想不到的具體設計 | **JOINT** | 雙方缺一不可 |
| 有疑問時 | **JOINT** | 保守預設 |

**邊界案例說明：**
- 使用者說「composer.lock 這種情況有考慮嗎？」→ **USER**（方向來自使用者，即使 AI 做了所有分類設計）
- 使用者問「為什麼噪音可以抵銷」→ **USER**（觸發者），AI 推導出 LLN 公式（技術貢獻大），但問題是使用者指出的 → 視具體情況；若 AI 的數學推導是核心產出，可標 **JOINT**
- AI 主動發現 rebase 造成 git diff 雜訊，使用者才知道這個問題 → **AI**
- 使用者說「要保留調整彈性」，AI 設計 weights.json + apply_curve() 具體架構 → **JOINT**（使用者指方向，AI 給具體設計）
- AI 只是把使用者直覺寫成結構化條目 → **USER**（結構化不算 AI 主導）

## Output Format

```
┌─ [SESSION | USER] 邏輯記錄 #003 ──────────────────────────┐
│ 📌 主題：為什麼不用行數估工時                               │
│                                                            │
│ ❓ 問題/動機                                               │
│   v2 用行數對照工時，但 1 行 race condition 可能花 3 天     │
│                                                            │
│ 🧠 直覺與推理                                              │
│   使用者：「行數多通常確實費時，但行數少不代表簡單」         │
│   AI：識別此為代理變數謬誤——相關性不等於因果               │
│                                                            │
│ 💭 推理過程                                                │
│   1. 行數是工時的代理指標，通常相關                        │
│   2. race condition 只有 1 行，卻需要 3 天                 │
│   3. 代理指標在邊界案例失效                                │
│   4. 語意複雜度才是真正的驅動因素                          │
│                                                            │
│ 🔍 考量維度                                                │
│   · 行數 vs 腦力投入的相關性                               │
│   · 機械式變動 vs 人工 code                                │
│   · 系統性偏差 vs 隨機誤差                                 │
│                                                            │
│ ❌ 排除項目（為什麼）                                       │
│   改用 modules 數 → 同樣是規則式判斷，本質相同             │
│                                                            │
│ ✅ 結論                                                    │
│   行數只作為正向信號，最終靠語意判斷                        │
│                                                            │
│ ⚠️ 前提假設                                               │
│   · 語意判斷能力足夠準確                                   │
│                                                            │
│ 📚 背後理論（AI 識別）                                     │
│   · 代理變數謬誤：用易量化指標替代真實目標，相關 ≠ 因果    │
│   · 大數法則：大樣本隨機誤差收斂，系統性偏差不會           │
│                                                            │
│ 🔗 supersedes #001                                         │
│ 📁 2026-05-15 14:23                                        │
└────────────────────────────────────────────────────────────┘
```

帶 `📎 補充` 的範例：

```
│ 📎 補充                                                    │
│   [經典案例]                                               │
│     · Economist：紙本 $125、網路版 $59、兩者 $125          │
│   [延伸閱讀]                                               │
│     · Ariely, Predictably Irrational, Ch.1                 │
```

### 欄位規則

| 欄位 | 必填 | 說明 | 長度參考 |
|------|------|------|----------|
| 類型標籤 | ✅ | `[SESSION \| USER]`、`[INSIGHT \| AI]` 等 | — |
| 📌 主題 | ✅ | 一句話描述核心問題 | 一行 |
| ❓ 問題/動機 | ✅ | 什麼情況觸發了這個分析？ | 1-3 行 |
| 🧠 直覺與推理 | ✅ | 用 `使用者：` / `AI：` 標注各自貢獻；USER 記錄保留使用者原話 | 各 1-2 行 |
| 💭 推理過程 | ✅ | 邏輯推導的步驟，numbered list，展示思路如何一步步到結論 | 3-6 步，每步一行 |
| 🔍 考量維度 | ✅ | 至少 2 個面向，每個 bullet 一行 | 2-5 條 |
| ❌ 排除項目 | 選填 | 有排除方案時才填，每條說明排除原因 | 1-3 條 |
| ✅ 結論 | ✅ | 最終判斷或選擇，散文不用 bullet | 1-2 行 |
| ⚠️ 前提假設 | 選填 | 結論成立的關鍵前提；前提若改變則結論需重新評估 | 1-3 條 |
| 📎 補充 | 選填 | 自訂子標籤 `[名稱]` + bullet，可多個子標籤 | 依需要 |
| 📚 背後理論 | ✅ | 每個理論一條，附一句說明如何解釋此推理 | 1-4 條 |
| 🔗 關聯 | 選填 | 有關聯記錄時填 | 1-3 條 |
| 📁 時間戳 | ✅ | `YYYY-MM-DD HH:MM` | 一行 |

## Numbering

使用 SessionStart hook 注入的起始編號，session 內自行遞增：

- Context 中若有「下一筆記錄從 #NNN 開始」→ 從 NNN 開始，每筆 +1
- 若無此注入 → 從 #001 開始

編號格式：三位數補零（#001、#042、#123）。

同一回應觸發兩筆（SESSION + INSIGHT）時，使用連續編號：先輸出 SESSION（#NNN），再輸出 INSIGHT（#NNN+1），兩筆各自存入 index.md。

index.md 的 TYPE 欄格式：`SESSION:USER`、`SESSION:AI`、`SESSION:JOINT`、`INSIGHT:USER` 等。

## Theory Identification

**開放式識別，不限學科，不限清單。**

使用者不需要知道理論名稱。AI 用自身知識庫辨識推理背後的理論或原則：

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

輸出記錄區塊後，立即用 **Bash 工具** 儲存到三個位置。

**取得儲存路徑：**
```bash
LOG_DIR="${LOGIC_LOG_DIR:-$HOME/.claude/logic-logs}"
```

**取得 session 資訊（從 SessionStart hook 注入的 context）：**

```
**Claude Session ID：** abc123-def456
**Session 開始時間：** 2026-05-15-14-23
**專案：** my-project
**下一筆記錄從 #008 開始**
```

儲存時從此 context 讀取 `session_id` 和 `session_start`。若找不到，使用 `unknown` 作為 fallback。

### 1. Session 完整記錄（JSONL）

檔案：`$LOG_DIR/sessions/{session_id}.jsonl`
操作：append 一行 JSON（`ensure_ascii=False` 保留中文）。

**JSON 結構：**
```json
{
  "id": 3,
  "type": "SESSION",
  "source": "USER",
  "topic": "為什麼不用行數估工時",
  "timestamp": "2026-05-15 14:23",
  "session_id": "abc123-def456",
  "session_start": "2026-05-15-14-23",
  "project": "my-project",
  "motivation": "v2 用行數對照工時，但 1 行 race condition 可能花 3 天",
  "reasoning": {
    "user": "行數多通常確實費時，但行數少不代表簡單",
    "ai": "識別此為代理變數謬誤——相關性不等於因果"
  },
  "reasoning_steps": [
    "行數是工時的代理指標，通常相關",
    "race condition 只有 1 行，卻需要 3 天",
    "代理指標在邊界案例失效",
    "語意複雜度才是真正的驅動因素"
  ],
  "dimensions": [
    "行數 vs 腦力投入的相關性",
    "機械式變動 vs 人工 code",
    "系統性偏差 vs 隨機誤差"
  ],
  "excluded": ["改用 modules 數 → 同樣是規則式判斷，本質相同"],
  "conclusion": "行數只作為正向信號，最終靠語意判斷",
  "assumptions": ["語意判斷能力足夠準確"],
  "additional": {},
  "theories": ["代理變數謬誤", "大數法則"],
  "relations": ["supersedes #001"]
}
```

**寫入方式：**
```bash
python3 << 'PYEOF'
import json
record = {
    # ... 填入上方 JSON 結構的實際內容
}
import os
log_dir = os.environ.get('LOGIC_LOG_DIR', os.path.expanduser('~/.claude/logic-logs'))
session_id = "SESSION_ID_HERE"
path = f"{log_dir}/sessions/{session_id}.jsonl"
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'a', encoding='utf-8') as f:
    f.write(json.dumps(record, ensure_ascii=False) + '\n')
print(f"✓ 已寫入 {path}")
PYEOF
```

### 2. 摘要索引（index.md）

檔案：`$LOG_DIR/index.md`
操作：append 一行（格式不變）：

```
#NNN | YYYY-MM-DD HH:MM | {session_id} | {session_start} | TYPE:SOURCE | 主題 | 理論1·理論2
```

### 3. Theory Ledger（theories.md）

檔案：`$LOG_DIR/theories.md`
操作：對每個識別到的理論：

**比對方式：** 讀取 theories.md，搜尋 `## 理論名稱` 區塊標題。中英文視為同一條目。theories.md 不存在則先建立空檔案。

**找到對應條目** → 在「應用記錄」區塊 append：
```
- #NNN | TYPE:SOURCE | {project} | {session_id} | Session大主題 | 當筆主題 | 2-3句說明此理論如何被應用
```

**找不到對應條目** → append 新條目：
```markdown
## 理論名稱（英文名）
核心：3-4 句通用說明（不含特定案例細節）。

應用記錄：
- #NNN | TYPE:SOURCE | {project} | {session_id} | Session大主題 | 當筆主題 | 描述
```
