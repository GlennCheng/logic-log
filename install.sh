#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_FILE="$HOME/.claude/settings.json"
INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

echo "🔧 Installing logic-log plugin from: $PLUGIN_DIR"

# ── 1. 確認 settings.json 存在 ───────────────────────────────
if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
fi

# ── 2. 加入 SessionStart hook ────────────────────────────────
echo "  → Adding SessionStart hook to settings.json..."

python3 - << PYEOF
import json, sys

settings_file = "$SETTINGS_FILE"
plugin_dir = "$PLUGIN_DIR"
hook_cmd = 'bash "' + plugin_dir + '/hooks-handlers/session-start.sh"'

with open(settings_file, 'r') as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})
session_start = hooks.setdefault('SessionStart', [])

# 檢查是否已有此 hook，避免重複
already_installed = any(
    any(h.get('command', '') == hook_cmd for h in entry.get('hooks', []))
    for entry in session_start
)

if not already_installed:
    session_start.append({
        "matcher": "",
        "hooks": [{"type": "command", "command": hook_cmd}]
    })
    with open(settings_file, 'w') as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
    print("    ✓ SessionStart hook added")
else:
    print("    ✓ SessionStart hook already present, skipping")
PYEOF

# ── 3. 登記到 installed_plugins.json ────────────────────────
echo "  → Registering plugin in installed_plugins.json..."

python3 - << PYEOF
import json, sys

installed_file = "$INSTALLED_PLUGINS"
plugin_dir = "$PLUGIN_DIR"
now = "$NOW"

with open(installed_file, 'r') as f:
    installed = json.load(f)

plugins = installed.setdefault('plugins', {})
key = "logic-log@local"

if key not in plugins:
    plugins[key] = [{
        "scope": "user",
        "installPath": plugin_dir,
        "version": "1.0.0",
        "installedAt": now,
        "lastUpdated": now
    }]
    with open(installed_file, 'w') as f:
        json.dump(installed, f, indent=2, ensure_ascii=False)
    print("    ✓ Plugin registered")
else:
    # 更新 installPath（避免移動資料夾後失效）
    plugins[key][0]['installPath'] = plugin_dir
    plugins[key][0]['lastUpdated'] = now
    with open(installed_file, 'w') as f:
        json.dump(installed, f, indent=2, ensure_ascii=False)
    print("    ✓ Plugin already registered, updated path")
PYEOF

# ── 4. 加入 enabledPlugins ───────────────────────────────────
echo "  → Enabling plugin in settings.json..."

python3 - << PYEOF
import json

settings_file = "$SETTINGS_FILE"

with open(settings_file, 'r') as f:
    settings = json.load(f)

enabled = settings.setdefault('enabledPlugins', {})
enabled['logic-log@local'] = True

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)

print("    ✓ Plugin enabled")
PYEOF

echo ""
echo "✅ logic-log installed successfully!"
echo ""
echo "   Restart Claude Code to activate the SessionStart hook."
echo "   Use /llog to query your logic records."
echo ""
echo "   Storage: ~/.claude/logic-logs/"
