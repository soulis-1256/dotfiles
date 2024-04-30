#!/bin/bash

# add this to debug
#exec > /tmp/debug_mic.log 2>&1

# add your node from pactl list sources
node="alsa_input.pci-0000_00_1f.3.analog-stereo"
# laptop
#node="alsa_input.pci-0000_00_1b.0.analog-stereo"

# Function to check if target node exists
check_target_node() {
    # Run pactl command to list sources and grep for the target node
    pactl list sources | grep -q "Name: $node"
}

sleep_time=1
# Loop until target node exists
while ! check_target_node; do
    echo "Target node not available, retrying in $sleep_time seconds..."
    sleep $sleep_time
done

echo "Target node is now available"

# Create a flag file to indicate that the node is available
touch /tmp/mic_recording_node_available.flag

# Start pw-record in the background
pw-record --target $node - | {

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
