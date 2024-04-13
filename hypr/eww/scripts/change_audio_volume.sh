#!/bin/bash

# Check if exactly two arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 [sink|source] [up|down|toggle]" >&2
    exit 1
fi

if [[ $2 != "toggle" ]]; then
    # Determine the audio device based on the first argument
    case "$1" in
        sink)
            audio_device="@DEFAULT_AUDIO_SINK@"
            ;;
        source)
            audio_device="@DEFAULT_AUDIO_SOURCE@"
            ;;
        *)
            echo "Usage: $0 [sink|source] [up|down|toggle]" >&2
            exit 1
            ;;
    esac

    # Determine the volume adjustment based on the second argument
    case "$2" in
        up)
            adjustment="0.01+"
            ;;
        down)
            adjustment="0.01-"
            ;;
        *)
            echo "Usage: $0 [sink|source] [up|down|toggle]" >&2
            exit 1
            ;;
    esac

    # Adjust the volume
    wpctl set-volume "$audio_device" "$adjustment" --limit 1.0
else
    if [[ $1 == "sink" ]]; then
        sink_status=$(pactl get-sink-mute @DEFAULT_SINK@)
        if [[ $sink_status == "Mute: no" ]]; then
            eww update sink_muted=true
        else
            eww update sink_muted=false
        fi
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    elif [[ $1 == "source" ]]; then
        source_status=$(pactl get-source-mute @DEFAULT_SOURCE@)
        if [[ $source_status == "Mute: no" ]]; then
            nohup play ~/Music/mute.wav vol 0.2 </dev/null >/dev/null 2>&1 &
            eww update source_muted=true
        else
            nohup play ~/Music/unmute.wav vol 0.2 </dev/null >/dev/null 2>&1 &
            eww update source_muted=false
        fi
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        exit 0
    else
        echo "Usage: $0 [sink|source] [up|down|toggle]" >&2
        exit 1
    fi
fi