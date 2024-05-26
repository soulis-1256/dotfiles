#!/bin/bash

# Function to fetch and process workspaces
spaces() {
    WORKSPACES=$(hyprctl workspaces -j)
    echo "$WORKSPACES" | jq -Mc 'group_by(.monitorID) | map({key: (.[0].monitorID|tostring), value: map({id: .id, windows: .windows, name: .name, focused: .focused, visible: .visible, monitor: .monitorID})}) | from_entries'
}

# Initial fetch and display of workspaces
spaces

# Listen for events and update workspaces accordingly
socat -u UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | while read -r line; do
    spaces
done

