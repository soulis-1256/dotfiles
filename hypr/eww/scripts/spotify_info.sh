#!/bin/bash

# Infinite loop
while true; do
    # Send D-Bus request to Spotify for info
    info=$(dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.GetAll string:'org.mpris.MediaPlayer2.Player')

    # Extract artist name and song name
    song=$(echo "$info" | awk '/xesam:title/{getline; print}' | awk -F '"' '{print $2}')
    artist=$(echo "$info" | awk '/xesam:artist/{getline; getline; print}' | awk -F '"' '{print $2}')
    time=$(echo "$info" | awk '/Position/{getline; print}' | awk -F ' ' '{printf "%d:%02d", $3/1000000/60, $3/1000000%60}')
    status=$(echo "$info" | awk '/PlaybackStatus/{getline; print}' | awk -F '"' '{print $2}')
    length=$(echo "$info" | awk '/mpris:length/{getline; print}' | awk -F ' ' '{printf "%d:%02d", $3/1000000/60, $3/1000000%60}')
    
    if [[ "$status" == "Playing" ]] ; then
        # Print artist name, song name, playback status, time, and length in one line
        echo "$artist - $song | $time/$length"
    fi

    sleep 1
done
