#!/usr/bin/env bash
#
# Simple tests for `theme-switcher sync-back`.
# Fully sandboxed (fake HOME + fake themes dir); never touches live
# config or the repo. Run from anywhere:
#   ./test-sync-back.sh
#
set -euo pipefail

BIN_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
SWITCHER="${BIN_DIR}/theme-switcher"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="${TMP}/home"
export THEME_SWITCHER_THEMES_DIR="${TMP}/themes"
mkdir -p "${HOME}/.config/DankMaterialShell" "${TMP}/themes/windows-11"

# Fixture theme pack: one bar, lucide icons.
cat > "${TMP}/themes/windows-11/dms-settings.json" <<'EOF'
{
  "barConfigs": [
    {
      "id": "default",
      "name": "Main Bar"
    }
  ],
  "iconPack": "lucide"
}
EOF

# Fixture live: drifted barConfigs + junk that must never travel,
# plus an iconPack drift outside the curated allowlist.
cat > "${HOME}/.config/DankMaterialShell/settings.json" <<'EOF'
{
  "barConfigs": [
    {"id": "default", "name": "Main Bar", "extraWidget": true}
  ],
  "iconPack": "phosphor",
  "hyprlandOutputSettings": {"DP-99": {}},
  "browserUsageHistory": {"firefox": 42}
}
EOF
echo "windows-11" > "${HOME}/.config/.current_theme"

PACK="${TMP}/themes/windows-11/dms-settings.json"
LIVE="${HOME}/.config/DankMaterialShell/settings.json"
SUM_BEFORE="$(sha256sum "$PACK" | cut -d' ' -f1)"

fail() {
    echo "FAIL: $1"
    exit 1
}

# 1. Dry run reports drift, touches nothing.
OUT="$(bash "$SWITCHER" sync-back --theme windows-11)"
echo "$OUT" | grep -q "barConfigs" || fail "dry run should mention barConfigs"
echo "$OUT" | grep -qi "dry run" || fail "dry run should say it is a dry run"
[ "$(sha256sum "$PACK" | cut -d' ' -f1)" == "$SUM_BEFORE" ] || fail "dry run modified the theme file"
echo "PASS: dry run reports drift, theme file untouched"

# 2. Curated allowlist holds: junk and non-listed drift stay out of the diff.
echo "$OUT" | grep -q "DP-99" && fail "machine state leaked into diff"
echo "$OUT" | grep -q "browserUsageHistory" && fail "histories leaked into diff"
echo "$OUT" | grep -q "phosphor" && fail "non-allowlisted iconPack drift leaked into diff"
echo "PASS: machine state and non-listed keys excluded"

# 3. Explicit --keys overrides the allowlist.
OUT_KEYS="$(bash "$SWITCHER" sync-back --theme windows-11 --keys iconPack)"
echo "$OUT_KEYS" | grep -q "phosphor" || fail "--keys override should include iconPack drift"
echo "PASS: --keys override works"

# 4. Apply promotes curated keys only.
bash "$SWITCHER" sync-back --theme windows-11 --apply > /dev/null
python3 - "$PACK" "$LIVE" <<'PY'
import json
import sys
pack = json.load(open(sys.argv[1]))
live = json.load(open(sys.argv[2]))
assert pack["barConfigs"] == live["barConfigs"], "barConfigs not promoted"
assert pack["iconPack"] == "lucide", "non-listed key must not be overwritten"
assert "hyprlandOutputSettings" not in pack, "machine state must not travel"
assert "browserUsageHistory" not in pack, "histories must not travel"
print("PASS: apply promotes curated keys only")
PY

# 5. Second run is clean (idempotent).
OUT2="$(bash "$SWITCHER" sync-back --theme windows-11)"
echo "$OUT2" | grep -qi "already in sync" || fail "second run should report clean"
echo "PASS: second run clean (idempotent)"

# 6. Unknown theme errors out.
if bash "$SWITCHER" sync-back --theme nope-theme > /dev/null 2>&1; then
    fail "unknown theme should error"
fi
echo "PASS: unknown theme errors"

# 7. No theme-pack 'pack' identifiers left in theme-switcher.
if grep -n -i "pack" "$SWITCHER" | grep -v -i "pdata\|plugin" | grep -q .; then
    fail "theme-pack pack remnants in theme-switcher"
fi
echo "PASS: no theme-pack pack remnants"

echo "ALL TESTS PASSED"
