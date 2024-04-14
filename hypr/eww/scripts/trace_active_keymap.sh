#!/bin/bash

# Function to determine active keymap
get_active_keymap() {
    local active_keymap
    active_keymap=$(hyprctl devices -j | jq -r '.keyboards[] | select(.name == "razer-razer-blackwidow-v3-tenkeyless").active_keymap')

    if [[ -n $active_keymap ]]; then
        if [[ -z $1 ]]; then
            if [[ $active_keymap == "English (US)"  ]]; then
                echo "en"
            elif [[ $active_keymap == "Greek" ]]; then
                echo "gr"
            else
                echo $active_keymap
            fi
        elif [[ $1 == "full" ]]; then
            echo $active_keymap
        fi
    else
        echo "error_keymap"
    fi
}

count=0
meta_pressed=false
previous_key=""

# Run active_keymap once to initialize the output
echo "$(get_active_keymap $1)"

# Monitor keyboard input
# If you need to run this as sudo (if you notice changing language doesnt get detected),
# add the following to /etc/sudoers:
# <username> ALL=(ALL:ALL) NOPASSWD: /usr/bin/showmethekey-cli
showmethekey-cli 2>/dev/null | grep --line-buffered -oP '(LEFTMETA|SPACE)' | while read -r key; do
    if [[ $key == "LEFTMETA" ]]; then
        if $meta_pressed; then
            meta_pressed=false
            if [[ $previous_key == "SPACE" ]]; then
                echo "$(get_active_keymap $1)"
            fi
        else
            meta_pressed=true
        fi
    elif $meta_pressed && [[ $key == "SPACE" ]]; then
        ((count++))
        if (( count % 2 == 0 )); then
            echo "$(get_active_keymap $1)"
        fi
    else
        count=0
        meta_pressed=false
    fi
    previous_key="$key"
done