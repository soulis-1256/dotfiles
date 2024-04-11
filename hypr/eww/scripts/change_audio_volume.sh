#/bin/bash

if test $1 == "up"; then
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.01+ --limit 1.0
elif test $1 == "down"; then
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.01-
fi
