#!/bin/bash

# Check if exactly one argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [sink|source]" >&2
    exit 1
fi

# Determine the audio device based on the argument and initialize mute status
case "$1" in
    sink)
        audio_device="@DEFAULT_AUDIO_SINK@"
        sink_status=$(pactl get-sink-mute @DEFAULT_SINK@)
        if [[ $sink_status == "Mute: no" ]]; then
            eww update sink_muted=false
        else
            eww update sink_muted=true
        fi
        ;;
    source)
        audio_device="@DEFAULT_AUDIO_SOURCE@"
        if [[ $source_status == "Mute: no" ]]; then
            eww update source_muted=false
        else
            eww update source_muted=true
        fi

        ;;
    *)
        echo "Usage: $0 [sink|source]" >&2
        exit 1
        ;;
esac

# Initialize previous volume
prev_volume=""

while true; do
    # Get current volume
    current_volume=$(wpctl get-volume "$audio_device" | awk -F': ' '{print $2 * 100}')

    # Check if the current volume is different from the previous one
    if [ "$current_volume" != "$prev_volume" ]; then
        echo "$current_volume"
        prev_volume="$current_volume"
    fi
done
