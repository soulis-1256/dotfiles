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

backup_conflicts() {
    local packages=("$@")
    local backup_dir="${TARGET_DIR}/.config_backup_$(date +%Y%m%d_%H%M%S)"
    local conflicts_found=false

    for pkg in "${packages[@]}"; do
        local pkg_path="${DOTFILES_DIR}/${pkg}"
        if [[ ! -d "$pkg_path" ]]; then
            continue
        fi

        # Check top-level dotfiles (e.g. ~/.bashrc)
        for item in "$pkg_path"/.*; do
            local base
            base="$(basename "$item")"
            [[ "$base" == "." || "$base" == ".." || "$base" == ".config" || "$base" == ".local" ]] && continue
            local target_file="${TARGET_DIR}/${base}"
            if [[ -e "$target_file" && ! -L "$target_file" ]]; then
                conflicts_found=true
                if [[ "$DRY_RUN" == true ]]; then
                    echo -e "${YELLOW}[Backup Preview]${NC} Physical file: ${target_file} -> will be moved to backup"
                else
                    mkdir -p "$backup_dir"
                    mv "$target_file" "$backup_dir/"
                    echo -e "${GREEN}[Backup]${NC} Moved ${target_file} -> ${backup_dir}/${base}"
                fi
            fi
        done

        # Check .config directories
        if [[ -d "$pkg_path/.config" ]]; then
            for dir in "$pkg_path/.config"/*; do
                local base
                base="$(basename "$dir")"
                local target_dir="${TARGET_DIR}/.config/${base}"
                if [[ -e "$target_dir" && ! -L "$target_dir" ]]; then
                    # If target_dir is a stow-folded directory containing links into dotfiles, skip backup
                    if find "$target_dir" -maxdepth 2 -type l -exec readlink {} + 2>/dev/null | grep -q "dotfiles"; then
                        continue
                    fi
                    conflicts_found=true
                    if [[ "$DRY_RUN" == true ]]; then
                        echo -e "${YELLOW}[Backup Preview]${NC} Physical directory: ${target_dir} -> will be moved to backup"
                    else
                        mkdir -p "$backup_dir/.config"
                        mv "$target_dir" "$backup_dir/.config/"
                        echo -e "${GREEN}[Backup]${NC} Moved ${target_dir} -> ${backup_dir}/.config/${base}"
                    fi
                fi
            done
        fi
    done

    if [[ "$conflicts_found" == true && "$DRY_RUN" == false ]]; then
        echo -e "${GREEN}All existing physical files safely backed up to: ${BOLD}${backup_dir}${NC}\n"
    fi
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
        stow -D -v -t "$TARGET_DIR" "${packages[@]}"
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

    local stow_flags=("-v" "-t" "$TARGET_DIR")
    cd "$DOTFILES_DIR"
    stow "${stow_flags[@]}" "${packages[@]}"

    echo -e "\n${GREEN}[SUCCESS] Dotfiles deployed successfully for profile '${detected_profile}'.${NC}"
    if command -v hyprctl &>/dev/null; then
        echo -e "${BLUE}Reloading Hyprland configuration...${NC}"
        hyprctl reload || true
    fi
}

main "$@"
