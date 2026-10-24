#!/bin/sh
# Link the OpenRGB theme hook into this desktop. install.sh does not do this.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repo=$(CDPATH= cd -- "$root/../.." && pwd)

link() {
  dest=$1
  src=$2
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    printf 'openrgb-theme: refusing to replace a real file: %s\n' "$dest" >&2
    exit 1
  fi
  ln -sfn "$src" "$dest"
}

if [ ! -d "$repo/desktop/.config/matugen" ]; then
  printf 'openrgb-theme: desktop matugen config is missing\n' >&2
  exit 1
fi

link "$repo/desktop/.config/matugen/templates/openrgb.hex" "$root/openrgb.hex"
link "$repo/desktop/.config/matugen/dms/configs/openrgb.toml" "$root/openrgb.toml"
link "${HOME}/.local/bin/openrgb-theme" "$root/openrgb-theme"
chmod +x "$root/openrgb-theme"

printf 'OpenRGB theme hook installed for this desktop.\n'
printf 'Undo with %s/disable.sh\n' "$root"
