#!/bin/bash

# Check if an argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <app_name>"
    exit 1
fi

# App name provided as argument
app_name="$1"

# Run hyprctl clients and store the output
clients_output=$(hyprctl clients)

# Variable to store the workspace containing the app
app_workspace=""

# Iterate over each line of the output
while IFS= read -r line; do
    # Check if the line contains workspace information
    if [[ $line =~ workspace:\ ([0-9]+) ]]; then
        workspace="${BASH_REMATCH[1]}"
    fi
    
    # Check if the line contains the app name in the initialTitle
    if [[ $line =~ initialTitle:\ $app_name ]]; then
        app_workspace="$workspace"
    fi
done <<< "$clients_output"

# If app workspace is found, switch to it
if [ -n "$app_workspace" ]; then
    echo "$app_name found on Workspace $app_workspace. Switching..."
    hyprctl dispatch workspace "$app_workspace"
else
    echo "$app_name is not running."
fi
