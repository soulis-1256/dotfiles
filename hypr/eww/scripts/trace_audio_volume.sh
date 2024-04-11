#!/bin/bash

# Initialize previous volume
prev_volume=""

while true; do
    # Get current volume
    current_volume=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk -F': ' '{print $2 * 100}')

    # Check if the current volume is different from the previous one
    if [ "$current_volume" != "$prev_volume" ]; then
        echo "$current_volume"
        prev_volume="$current_volume"
    fi
done
