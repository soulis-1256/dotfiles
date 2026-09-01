#!/usr/bin/env bash
#
# Dotfiles Deployment & Stow Manager
# Supports automatic chassis detection (desktop vs laptop), display detection, dry-run testing, and backups.
#

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}"

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

DRY_RUN=false
UNSTOW=false
BACKUP=true
PROFILE=""

print_header() {
    echo -e "${BOLD}${BLUE}=== Dotfiles Deployment Manager ===${NC}"
}

usage() {
    cat << EOF
Usage: ./install.sh [OPTIONS]

Options:
    -n, --dry-run        Simulate deployment and test for conflicts (no changes made)
    -p, --profile NAME   Force a specific profile: 'desktop', 'laptop', or 'common'
    -D, --unstow         Remove symlinks created by Stow
    --no-backup          Skip automatic backup of conflicting physical directories
    -h, --help           Show this help message

Examples:
    ./install.sh --dry-run          # Test what would be linked on this machine
    ./install.sh                    # Auto-detect hardware and deploy symlinks
    ./install.sh --profile laptop   # Force laptop profile deployment
EOF
    exit 0
}

# Parse CLI flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -p|--profile)
            PROFILE="$2"
            shift 2
            ;;
        -D|--unstow)
            UNSTOW=true
            shift
            ;;
        --no-backup)
            BACKUP=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Detect connected display ports
get_connected_monitors() {
    local ports=()
    for status_file in /sys/class/drm/card*-*/status; do
        if [[ -f "$status_file" ]] && grep -q "^connected$" "$status_file" 2>/dev/null; then
            local port
            port="$(basename "$(dirname "$status_file")" | sed 's/card[0-9]*-//')"
            ports+=("$port")
        fi
    done
    echo "${ports[@]}"
}

# Detect chassis / hardware type if not explicitly set
detect_profile() {
    if [[ -n "$PROFILE" ]]; then
        echo "$PROFILE"
        return
    fi

    # Check 1: hostnamectl chassis
    if command -v hostnamectl &>/dev/null; then
        local chassis
        chassis="$(hostnamectl chassis 2>/dev/null || true)"
        if [[ "$chassis" == "laptop" || "$chassis" == "notebook" || "$chassis" == "convertible" ]]; then
            echo "laptop"
            return
        fi
    fi

    # Check 2: internal eDP panel in sysfs
    if compgen -G "/sys/class/drm/*-eDP-*" > /dev/null; then
        echo "laptop"
        return
    fi

    # Check 3: Battery existence
    if compgen -G "/sys/class/power_supply/BAT*" > /dev/null; then
        echo "laptop"
        return
    fi

    echo "desktop"
}

check_prerequisites() {
    if ! command -v stow &>/dev/null; then
        echo -e "${RED}Error: GNU Stow is not installed.${NC}"
        echo -e "Install it using: ${BOLD}sudo pacman -S stow${NC}"
        exit 1
    fi
}

# Backup colliding regular files only. Never move a live directory such as
# ~/.config/hypr — Hyprland watches that path and a mid-session mv/unlink
# reloads a missing hyprland.lua. --no-folding lets Stow link into existing dirs.
backup_conflicts() {
    local packages=("$@")
    local backup_dir="${TARGET_DIR}/.config_backup_$(date +%Y%m%d_%H%M%S)"
    local conflicts_found=false

    for pkg in "${packages[@]}"; do
        local pkg_path="${DOTFILES_DIR}/${pkg}"
        if [[ ! -d "$pkg_path" ]]; then
            continue
        fi

        while IFS= read -r -d '' item; do
            local rel="${item#"${pkg_path}/"}"
            local target="${TARGET_DIR}/${rel}"

            # Directories stay in place so Stow --no-folding can link into them.
            # Existing symlinks are already Stow-managed (or user-owned links).
            if [[ -d "$target" || -L "$target" || ! -e "$target" ]]; then
                continue
            fi
            if [[ ! -f "$target" ]]; then
                continue
            fi

            # Folded Stow trees (e.g. ~/.config/nvim -> dotfiles/.../nvim) make
            # inner files look like regular files. Do not "back them up" out of the repo.
            local target_real item_real
            target_real="$(realpath "$target" 2>/dev/null || true)"
            item_real="$(realpath "$item" 2>/dev/null || true)"
            if [[ -n "$target_real" && ( "$target_real" == "$item_real" || "$target_real" == "$DOTFILES_DIR"/* ) ]]; then
                continue
            fi

            conflicts_found=true
            if [[ "$DRY_RUN" == true ]]; then
                echo -e "${YELLOW}[Backup Preview]${NC} Physical file: ${target} -> will be moved to backup"
            else
                mkdir -p "${backup_dir}/$(dirname "$rel")"
                mv "$target" "${backup_dir}/${rel}"
                echo -e "${GREEN}[Backup]${NC} Moved ${target} -> ${backup_dir}/${rel}"
            fi
        done < <(find "$pkg_path" -mindepth 1 -print0)
    done

    if [[ "$conflicts_found" == true && "$DRY_RUN" == false ]]; then
        echo -e "${GREEN}All existing physical files safely backed up to: ${BOLD}${backup_dir}${NC}\n"
    fi
}

# hyprctl needs HYPRLAND_INSTANCE_SIGNATURE; it is unset over SSH and on a TTY.
hyprctl_reload() {
    if ! command -v hyprctl &>/dev/null; then
        return 0
    fi

    local runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    local sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"

    if [[ -z "$sig" && -d "${runtime}/hypr" ]]; then
        local newest
        newest="$(ls -1dt "${runtime}"/hypr/*/ 2>/dev/null | head -n1 || true)"
        [[ -n "$newest" ]] && sig="$(basename "$newest")"
    fi

    if [[ -z "$sig" ]]; then
        echo -e "${YELLOW}Hyprland is not running; skipped reload.${NC}"
        return 0
    fi

    echo -e "${BLUE}Reloading Hyprland configuration...${NC}"
    XDG_RUNTIME_DIR="$runtime" HYPRLAND_INSTANCE_SIGNATURE="$sig" hyprctl reload >/dev/null || true
}

main() {
    print_header
    check_prerequisites

    local detected_profile
    detected_profile="$(detect_profile)"

    local connected_displays
    connected_displays="$(get_connected_monitors)"
    local display_count
    display_count="$(echo "$connected_displays" | wc -w)"

    echo -e "${BOLD}Hardware Chassis:${NC}    ${GREEN}${detected_profile}${NC}"
    echo -e "${BOLD}Connected Displays:${NC}  ${CYAN}${display_count}${NC} (${connected_displays:-none})"
    echo -e "${BOLD}Dotfiles Path:${NC}       ${DOTFILES_DIR}"
    echo -e "${BOLD}Target Home:${NC}         ${TARGET_DIR}"

    local packages=("common")
    if [[ "$detected_profile" == "desktop" ]]; then
        packages+=("desktop")
    elif [[ "$detected_profile" == "laptop" ]]; then
        packages+=("laptop")
    fi

    if [[ "$UNSTOW" == true ]]; then
        echo -e "\n${YELLOW}Unstowing packages:${NC} ${packages[*]}"
        cd "$DOTFILES_DIR"
        stow --no-folding -D -v -t "$TARGET_DIR" "${packages[@]}"
        echo -e "${GREEN}Unstow complete.${NC}"
        return
    fi

    if [[ "$BACKUP" == true ]]; then
        backup_conflicts "${packages[@]}"
    fi

    echo -e "\n${BOLD}Packages to deploy:${NC}   ${packages[*]}"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "\n${YELLOW}>>> DRY-RUN COMPLETE (No files were modified) <<<${NC}"
        echo -e "Run ${BOLD}./install.sh${NC} to execute automatic backup and deployment."
        return
    fi

    # --no-folding: never replace ~/.config/hypr with a directory symlink.
    # A later package (laptop.lua / desktop.lua) would unfold that symlink by
    # deleting the directory, and Hyprland's inotify reload would see a missing
    # hyprland.lua. Linking files into a real directory avoids that gap.
    local stow_flags=("--no-folding" "-v" "-t" "$TARGET_DIR")
    cd "$DOTFILES_DIR"
    stow "${stow_flags[@]}" "${packages[@]}"

    # Ensure DMS user service is enabled
    if command -v systemctl &>/dev/null && systemctl --user list-unit-files dms.service &>/dev/null; then
        systemctl --user enable dms.service >/dev/null 2>&1 || true
    fi

    echo -e "\n${GREEN}[SUCCESS] Dotfiles deployed successfully for profile '${detected_profile}'.${NC}"
    hyprctl_reload
}

main "$@"
