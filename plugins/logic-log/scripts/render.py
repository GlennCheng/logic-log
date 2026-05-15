#!/usr/bin/env python3
"""
Logic Log JSON → Box 格式渲染

Usage:
  python3 render.py <session.jsonl> [record_id]   # 從 JSONL 檔讀取
  echo '{...}' | python3 render.py                # 從 stdin 讀單筆 JSON
"""

import sys
import json
import unicodedata

TOTAL_WIDTH = 62
CONTENT_WIDTH = TOTAL_WIDTH - 4  # │ + space + content + space + │


def dw(s):
    """計算字串終端顯示寬度（CJK/emoji = 2, 其他 = 1）"""
    w = 0
    for c in s:
        cp = ord(c)
        ea = unicodedata.east_asian_width(c)
        if ea in ('W', 'F') or 0x1F000 <= cp <= 0x1FAFF:
            w += 2
        else:
            w += 1
    return w


def pad(s, width):
    return s + ' ' * max(0, width - dw(s))


def box_line(content=''):
    return f'│ {pad(content, CONTENT_WIDTH)} │'


def wrap(first_prefix, text, cont_prefix=None):
    """
    將 text 換行成多行，第一行用 first_prefix，continuation 用 cont_prefix。
    cont_prefix 預設為與 first_prefix 等寬的空格。
    """
    if cont_prefix is None:
        cont_prefix = ' ' * dw(first_prefix)

    result, cur, cur_dw_val, is_first = [], '', 0, True

    for ch in text:
        ch_dw_val = dw(ch)
        prefix = first_prefix if is_first else cont_prefix
        limit = CONTENT_WIDTH - dw(prefix)
        if cur_dw_val + ch_dw_val > limit:
            result.append(prefix + cur)
            cur, cur_dw_val, is_first = ch, ch_dw_val, False
        else:
            cur += ch
            cur_dw_val += ch_dw_val

    result.append((first_prefix if is_first else cont_prefix) + cur)
    return result


def render(r):
    out = []

    # Header
    type_src = f"[{r['type']} | {r['source']}]"
    id_str = f"#{r['id']:03d}"
    header = f"─ {type_src} 邏輯記錄 {id_str} "
    dashes = '─' * max(0, TOTAL_WIDTH - 2 - dw(header))
    out.append(f'┌{header}{dashes}┐')

    # 📌 主題
    for line in wrap('📌 主題：', r['topic']):
        out.append(box_line(line))
    out.append(box_line())

    # ❓ 問題/動機
    out.append(box_line('❓ 問題/動機'))
    for para in str(r.get('motivation', '')).splitlines():
        for line in wrap('   ', para):
            out.append(box_line(line))
    out.append(box_line())

    # 🧠 直覺與推理
    reasoning = r.get('reasoning') or {}
    user_r = reasoning.get('user')
    ai_r = reasoning.get('ai')
    if user_r or ai_r:
        out.append(box_line('🧠 直覺與推理'))
        if user_r:
            fp = '   使用者：'
            for line in wrap(fp, user_r):
                out.append(box_line(line))
        if ai_r:
            fp = '   AI：'
            for line in wrap(fp, ai_r):
                out.append(box_line(line))
        out.append(box_line())

    # 💭 推理過程
    steps = r.get('reasoning_steps', [])
    if steps:
        out.append(box_line('💭 推理過程'))
        for i, step in enumerate(steps, 1):
            fp = f'   {i}. '
            for line in wrap(fp, step):
                out.append(box_line(line))
        out.append(box_line())

    # 🔍 考量維度
    dims = r.get('dimensions', [])
    if dims:
        out.append(box_line('🔍 考量維度'))
        for d in dims:
            for line in wrap('   · ', d):
                out.append(box_line(line))
        out.append(box_line())

    # ❌ 排除項目
    excluded = r.get('excluded', [])
    if excluded:
        out.append(box_line('❌ 排除項目（為什麼）'))
        for e in excluded:
            for line in wrap('   ', e):
                out.append(box_line(line))
        out.append(box_line())

    # ✅ 結論
    out.append(box_line('✅ 結論'))
    for para in str(r.get('conclusion', '')).splitlines():
        for line in wrap('   ', para):
            out.append(box_line(line))
    out.append(box_line())

    # ⚠️ 前提假設
    assumptions = r.get('assumptions', [])
    if assumptions:
        out.append(box_line('⚠️ 前提假設'))
        for a in assumptions:
            for line in wrap('   · ', a):
                out.append(box_line(line))
        out.append(box_line())

    # 📎 補充
    additional = r.get('additional') or {}
    if additional:
        out.append(box_line('📎 補充'))
        for key, values in additional.items():
            out.append(box_line(f'   [{key}]'))
            items = values if isinstance(values, list) else [values]
            for v in items:
                fp = '     · '
                for line in wrap(fp, str(v)):
                    out.append(box_line(line))
        out.append(box_line())

    # 📚 背後理論
    theories = r.get('theories', [])
    if theories:
        out.append(box_line('📚 背後理論（AI 識別）'))
        for t in theories:
            for line in wrap('   · ', t):
                out.append(box_line(line))
        out.append(box_line())

    # 🔗 關聯
    for rel in r.get('relations', []):
        out.append(box_line(f'🔗 {rel}'))

    # 📁 時間戳
    out.append(box_line(f"📁 {r['timestamp']}"))
    out.append(f'└{"─" * (TOTAL_WIDTH - 2)}┘')

    return '\n'.join(out)


def main():
    if len(sys.argv) == 1:
        data = json.load(sys.stdin)
        print(render(data))
        return

    fname = sys.argv[1]
    target_id = int(sys.argv[2]) if len(sys.argv) > 2 else None

    with open(fname, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                continue
            if target_id is None or r.get('id') == target_id:
                print(render(r))
                if target_id is not None:
                    break


if __name__ == '__main__':
    main()
