#!/bin/bash

if [[ $# -ne 1 || ($1 != "up" && $1 != "down") ]]; then
    exit 1
fi

current_workspace=$(hyprctl activewindow | grep "workspace: " | awk '{print $2}')

workspaces=$(hyprctl workspaces | grep "workspace ID" | awk '{print $3}' | sort -n)

if [[ $1 == "up" ]]; then
    max_workspace=$(echo "$workspaces" | tail -n 1)
    if [[ $current_workspace -ne $max_workspace ]]; then
        hyprctl dispatch workspace e+1
    fi
elif [[ $1 == "down" ]]; then
    min_workspace=$(echo "$workspaces" | head -n 1)
    if [[ $current_workspace -ne $min_workspace ]]; then
        hyprctl dispatch workspace e-1
    fi
fi

exit 0