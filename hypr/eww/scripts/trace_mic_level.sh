#!/bin/bash

tail -f /tmp/mic_recording.txt | while read line; do
    mic_level=$(echo "$line" | awk '/Maximum amplitude:/ {printf("%.0f\n", $NF * 100)}')
    #if [[  $mic_level -gt 1 ]]; then
    #    echo 100
        #sleep 0.1
    #else
    #    echo 0
    #fi
    echo $mic_level
done
