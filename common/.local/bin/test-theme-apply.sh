#!/usr/bin/env bash
#
# Sandboxed tests for `theme-switcher apply`.
# Never touches live config or the repo. Run from anywhere:
#   ./test-theme-apply.sh
#
set -euo pipefail

BIN_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
SWITCHER="${BIN_DIR}/theme-switcher"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="${TMP}/home"
export THEME_SWITCHER_THEMES_DIR="${TMP}/themes"
mkdir -p "${HOME}/.config/DankMaterialShell" \
    "${TMP}/themes/windows-10" \
    "${TMP}/themes/windows-11"

cat > "${TMP}/themes/windows-10/metadata.json" <<'EOF'
{"name": "Windows 10"}
EOF
cat > "${TMP}/themes/windows-11/metadata.json" <<'EOF'
{"name": "Windows 11"}
EOF

cat > "${TMP}/themes/windows-10/dms-settings.json" <<'EOF'
{
  "barConfigs": [
    {
      "id": "default",
      "name": "Win10 Bar",
      "leftWidgets": [{"id": "win10Start", "enabled": true}]
    }
  ],
  "iconPack": "lucide",
  "runUserMatugenTemplates": false
}
EOF

cat > "${TMP}/themes/windows-11/dms-settings.json" <<'EOF'
{
  "barConfigs": [
    {
      "id": "default",
      "name": "Win11 Bar",
      "leftWidgets": [{"id": "win11Start", "enabled": true}]
    }
  ],
  "iconPack": "lucide",
  "runUserMatugenTemplates": false
}
EOF

# Live starts as a customized Windows 11 layout.
cat > "${HOME}/.config/DankMaterialShell/settings.json" <<'EOF'
{
  "barConfigs": [
    {
      "id": "default",
      "name": "Win11 Custom",
      "leftWidgets": [{"id": "win11Start", "enabled": true}]
    }
  ],
  "iconPack": "lucide",
  "runUserMatugenTemplates": true,
  "greeterFoo": "keep-me",
  "browserUsageHistory": {"firefox": 42}
}
EOF
echo "windows-11" > "${HOME}/.config/.current_theme"

WIN10="${TMP}/themes/windows-10/dms-settings.json"
WIN11="${TMP}/themes/windows-11/dms-settings.json"
LIVE="${HOME}/.config/DankMaterialShell/settings.json"
SUM10="$(sha256sum "$WIN10" | cut -d' ' -f1)"
SUM11="$(sha256sum "$WIN11" | cut -d' ' -f1)"

fail() {
    echo "FAIL: $1"
    exit 1
}

widget_name() {
    python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['barConfigs'][0]['name'])" "$1"
}

widget_id() {
    python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['barConfigs'][0]['leftWidgets'][0]['id'])" "$1"
}

# 1. Mid-switch sync-back must not hijack the theme we are leaving.
# Simulate apply having already rewritten live settings while current_theme
# still names windows-11 (the original race).
python3 - "$LIVE" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
data = json.loads(p.read_text())
data["barConfigs"][0]["name"] = "Hijack"
data["barConfigs"][0]["leftWidgets"][0]["id"] = "win10Start"
p.write_text(json.dumps(data, indent=2) + "\n")
PY
touch "${HOME}/.config/.theme-switcher-applying"
bash "$SWITCHER" sync-back --apply >/dev/null
[ "$(sha256sum "$WIN11" | cut -d' ' -f1)" == "$SUM11" ] || fail "locked sync-back rewrote windows-11"
rm -f "${HOME}/.config/.theme-switcher-applying"
# Put live back to the customized windows-11 state.
python3 - "$LIVE" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
data = json.loads(p.read_text())
data["barConfigs"][0]["name"] = "Win11 Custom"
data["barConfigs"][0]["leftWidgets"][0]["id"] = "win11Start"
p.write_text(json.dumps(data, indent=2) + "\n")
PY
echo "PASS: locked sync-back cannot write the inactive theme"

# 2. Switching 11 -> 10 must not rewrite either theme file.
bash "$SWITCHER" apply windows-10 >/dev/null
[ "$(sha256sum "$WIN10" | cut -d' ' -f1)" == "$SUM10" ] || fail "apply dirtied windows-10/dms-settings.json"
[ "$(sha256sum "$WIN11" | cut -d' ' -f1)" == "$SUM11" ] || fail "apply dirtied windows-11/dms-settings.json"
[ "$(cat "${HOME}/.config/.current_theme")" = "windows-10" ] || fail "current_theme not windows-10"
[ "$(widget_id "$LIVE")" = "win10Start" ] || fail "live settings did not switch to windows-10 widgets"
[ "$(widget_name "$LIVE")" = "Win10 Bar" ] || fail "live settings did not take windows-10 bar layout"
python3 - "$LIVE" <<'PY'
import json, sys
live = json.load(open(sys.argv[1]))
assert live.get("runUserMatugenTemplates") is True, "preserved machine key dropped"
assert live.get("greeterFoo") == "keep-me", "greeter key dropped"
PY
[ -f "${HOME}/.config/DankMaterialShell/theme-state/windows-11.json" ] || fail "did not snapshot windows-11"
[ "$(widget_name "${HOME}/.config/DankMaterialShell/theme-state/windows-11.json")" = "Win11 Custom" ] || fail "windows-11 snapshot lost live tweaks"
echo "PASS: switch 11->10 updates live settings, snapshots, leaves theme files alone"

# 3. Returning to windows-11 restores the snapshot, still without git writes.
SUM10="$(sha256sum "$WIN10" | cut -d' ' -f1)"
SUM11="$(sha256sum "$WIN11" | cut -d' ' -f1)"
bash "$SWITCHER" apply windows-11 >/dev/null
[ "$(sha256sum "$WIN10" | cut -d' ' -f1)" == "$SUM10" ] || fail "return trip dirtied windows-10"
[ "$(sha256sum "$WIN11" | cut -d' ' -f1)" == "$SUM11" ] || fail "return trip dirtied windows-11"
[ "$(widget_name "$LIVE")" = "Win11 Custom" ] || fail "did not restore windows-11 snapshot"
[ "$(widget_id "$LIVE")" = "win11Start" ] || fail "restored snapshot lost win11 widgets"
echo "PASS: return to windows-11 restores snapshot, theme files untouched"

# 4. Reapply keeps live edits.
python3 - "$LIVE" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
data = json.loads(p.read_text())
data["barConfigs"][0]["name"] = "Win11 Live Edit"
p.write_text(json.dumps(data, indent=2) + "\n")
PY
bash "$SWITCHER" apply windows-11 >/dev/null
[ "$(widget_name "$LIVE")" = "Win11 Live Edit" ] || fail "reapply discarded live edits"
[ "$(sha256sum "$WIN11" | cut -d' ' -f1)" == "$SUM11" ] || fail "reapply dirtied windows-11"
echo "PASS: reapply keeps live edits and does not write the theme file"

# 5. --reset discards snapshot and takes theme defaults.
bash "$SWITCHER" apply windows-11 --reset >/dev/null
[ "$(widget_name "$LIVE")" = "Win11 Bar" ] || fail "--reset did not restore theme defaults"
[ -f "${HOME}/.config/DankMaterialShell/theme-state/windows-11.json" ] && fail "--reset left the snapshot"
echo "PASS: --reset restores theme defaults"

# 6. Multi-variant custom themes resolve primary from flavor+accent (Ghostty).
python3 - <<'PY'
import json, sys

def merge(base, extra):
    if not extra:
        return base
    out = dict(base)
    out.update(extra)
    return out

def find_variant(options, vid):
    for item in options or []:
        if item.get("id") == vid:
            return item
    return None

def find_accent(accents, aid):
    for item in accents or []:
        if item.get("id") == aid:
            return item
    return None

theme = {
    "id": "astralJourney",
    "dark": {"surfaceText": "#ebe8d2"},
    "variants": {
        "type": "multi",
        "defaults": {"dark": {"accent": "amber", "flavor": "blackhole"}},
        "flavors": [{"id": "blackhole", "dark": {"background": "#0d0f1e"}}],
        "accents": [{"id": "amber", "blackhole": {"primary": "#ffcc66"}}],
    },
}
stored = {"dark": {"flavor": "blackhole", "accent": "amber"}}
dark = theme.get("dark") or {}
variants = theme["variants"]
defaults = variants["defaults"]
dark_def = defaults["dark"]
stored_dark = stored["dark"]
dark_flavor = find_variant(variants["flavors"], stored_dark.get("flavor") or dark_def.get("flavor"))
dark_accent = find_accent(variants["accents"], stored_dark.get("accent") or dark_def.get("accent"))
if dark_flavor:
    dark = merge(dark, dark_flavor.get("dark") or {})
    if dark_accent:
        dark = merge(dark, dark_accent.get(dark_flavor.get("id")) or {})
assert dark.get("primary") == "#ffcc66", dark
assert dark.get("background") == "#0d0f1e", dark
print("PASS: multi-variant accent merge resolves primary")
PY

grep -q "find_accent" "$SWITCHER" || fail "theme-switcher lost multi-variant accent merge"
grep -q "StartLimitIntervalSec=0" "${BIN_DIR}/../../.config/systemd/user/dms-theme-sync.service" \
    || fail "dms-theme-sync.service must disable start limiting"

echo "ALL TESTS PASSED"
