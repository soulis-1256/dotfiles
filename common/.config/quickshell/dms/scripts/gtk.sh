#!/usr/bin/env bash

CONFIG_DIR="$1"
SHELL_DIR="$3"

if [ -z "$CONFIG_DIR" ]; then
    echo "Usage: $0 <config_dir> [is_light] [shell_dir]" >&2
    exit 1
fi

# The light template references adw-gtk3 image assets relative to gtk.css
# (check/radio glyphs, slider knobs); without them checked boxes render as
# solid blocks.
link_gtk3_assets() {
    local gtk3_dir="$1"
    local assets_link="$gtk3_dir/assets"

    if [ -e "$assets_link" ] && [ ! -L "$assets_link" ]; then
        echo "Leaving user-managed $assets_link in place"
        return
    fi

    local candidates=(
        "$HOME/.local/share/themes/adw-gtk3/gtk-3.0/assets"
        "$HOME/.themes/adw-gtk3/gtk-3.0/assets"
        "/usr/share/themes/adw-gtk3/gtk-3.0/assets"
        "/usr/local/share/themes/adw-gtk3/gtk-3.0/assets"
    )
    local target=""
    for c in "${candidates[@]}"; do
        if [ -d "$c" ]; then
            target="$c"
            break
        fi
    done
    if [ -z "$target" ] && [ -n "$SHELL_DIR" ] && [ -d "$SHELL_DIR/matugen/gtk3-assets" ]; then
        target="$SHELL_DIR/matugen/gtk3-assets"
    fi
    if [ -z "$target" ]; then
        return
    fi

    ln -sfn "$target" "$assets_link"
    echo "Linked GTK3 assets: $assets_link -> $target"
}

apply_gtk3_colors() {
    local config_dir="$1"

    local gtk3_dir="$config_dir/gtk-3.0"
    local dank_colors="$gtk3_dir/dank-colors.css"
    local gtk_css="$gtk3_dir/gtk.css"

    if [ ! -f "$dank_colors" ]; then
        echo "Error: dank-colors.css not found at $dank_colors" >&2
        echo "Run matugen first to generate theme files" >&2
        exit 1
    fi

    if [ -L "$gtk_css" ]; then
        rm "$gtk_css"
    elif [ -f "$gtk_css" ]; then
        mv "$gtk_css" "$gtk_css.backup.$(date +%s)"
        echo "Backed up existing gtk.css"
    fi

    ln -s "dank-colors.css" "$gtk_css"
    echo "Created symlink: $gtk_css -> dank-colors.css"

    link_gtk3_assets "$gtk3_dir"
}

apply_gtk4_colors() {
    local config_dir="$1"

    local gtk4_dir="$config_dir/gtk-4.0"
    local dank_colors="$gtk4_dir/dank-colors.css"
    local gtk_css="$gtk4_dir/gtk.css"
    local gtk4_import="@import url(\"dank-colors.css\");"

    if [ ! -f "$dank_colors" ]; then
        echo "Error: GTK4 dank-colors.css not found at $dank_colors" >&2
        echo "Run matugen first to generate theme files" >&2
        exit 1
    fi

    if [ -f "$gtk_css" ] && grep -q '^@import url.*dank-colors\.css.*);$' "$gtk_css"; then
        echo "GTK4 import already exists"
        return
    fi

    if [ -f "$gtk_css" ] && [ -s "$gtk_css" ]; then
        sed -i "1i\\$gtk4_import" "$gtk_css"
    else
        echo "$gtk4_import" >"$gtk_css"
    fi
    echo "Updated GTK4 CSS import"
}

# Repair pass for shells whose gtk.css was linked before asset handling
# existed; only acts when DMS already manages gtk.css.
if [ "$4" = "assets-only" ]; then
    if [ -L "$CONFIG_DIR/gtk-3.0/gtk.css" ]; then
        link_gtk3_assets "$CONFIG_DIR/gtk-3.0"
    fi
    exit 0
fi

mkdir -p "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"

apply_gtk3_colors "$CONFIG_DIR"
apply_gtk4_colors "$CONFIG_DIR"

echo "GTK colors applied successfully"
