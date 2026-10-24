#!/bin/sh
# Remove the links enable.sh created. The files in this directory stay.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repo=$(CDPATH= cd -- "$root/../.." && pwd)

drop() {
  dest=$1
  if [ ! -L "$dest" ]; then
    return
  fi
  case $(readlink "$dest") in
    "$root"/*) rm "$dest" ;;
  esac
}

drop "$repo/desktop/.config/matugen/templates/openrgb.hex"
drop "$repo/desktop/.config/matugen/dms/configs/openrgb.toml"
drop "${HOME}/.local/bin/openrgb-theme"
rmdir "$repo/desktop/.config/matugen/dms/configs" 2>/dev/null || true
rmdir "$repo/desktop/.config/matugen/dms" 2>/dev/null || true

printf 'OpenRGB theme hook removed from this desktop.\n'
