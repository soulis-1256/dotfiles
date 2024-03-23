#!/bin/bash

# Kill wl-gammarelay-rs if it's running
if pgrep -f "wl-gammarelay-rs"; then
    pkill -f "wl-gammarelay-rs"
fi

# Start the watch process and get its PID
wl-gammarelay-rs watch {t} &
pid=$!

# Set the desired temperature
busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Temperature q 5000

# Wait for the watch process to finish (bring back to fg)
wait $pid