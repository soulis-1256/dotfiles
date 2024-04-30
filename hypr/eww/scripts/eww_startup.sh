#/bin/bash

~/.config/eww/scripts/spotify_status.sh &

~/.config/eww/scripts/mic_recording.sh &

# Wait until the flag file indicating the node is available is created
while [ ! -f /tmp/mic_recording_node_available.flag ]; do
    sleep 0.5
done

# Once the flag file is created, open the bar
eww open bar

exit 0