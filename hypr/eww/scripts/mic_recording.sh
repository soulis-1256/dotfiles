#!/bin/bash

# Start pw-record in the background
pw-record --target alsa_input.pci-0000_00_1f.3.analog-stereo - | {

    # Save pw-record's PID
    pw_record_pid=$!

    # Loop to continuously run sox and print stats
    while true; do
        nohup sox -t raw -r 44100 -e signed -b 16 -c 2 - -n stat >> /tmp/mic_recording.txt 2>&1 &
        sox_pid=$!
        sleep 0.1
        kill "$sox_pid" 2>/dev/null
    done
}
