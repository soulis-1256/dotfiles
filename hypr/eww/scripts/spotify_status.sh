#!/bin/bash

# Function to update music status or volume in eww
update_eww() {
    # Arguments:
    # $1: Key to update in eww (e.g., music_status or test_music)
    # $2: 'status' or 'volume'

    value=""
    if [[ $2 == "status" ]]; then
        value=$(playerctl --player spotify status)
        sleep 0.1
    elif [[ $2 == "volume" ]]; then
        value=$(playerctl --player spotify volume | awk '{printf "%.0f", $1 * 100}')
    fi

    if [[ $value == "" ]]; then
        value="N/A"
    fi

    eww update "$1"="$value"
}

lock=0

while true; do
    if [[ $(hyprctl clients | grep Spotify) == "" ]]; then
        if [[ $lock == 0 ]]; then
            # update status when spotify exits
            eww update music_status="spotify_exit"
            lock=1
        fi
    else
        if [[ $lock == 1 ]]; then
            lock=0
        fi
        
        # these work continuously
        update_eww "music_status" "status"
        update_eww "music_volume" "volume"
    fi
    sleep 1
done
