#!/bin/bash

# Function to check if an argument is an integer
is_integer() {
    [[ $1 =~ ^[0-9]+$ ]]
}

# Check if an integer argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <color_temperature>"
    exit 1
fi

# Check if the provided argument is an integer
if ! is_integer "$1"; then
    echo "Error: Argument must be an integer."
    exit 1
fi

# Check if the provided argument is within the range 0-10000
if (( $1 < 1000 || $1 > 10000 )); then
    echo "Error: Color temperature must be between 0 and 10000."
    exit 1
fi

# Kill wl-gammarelay-rs if it's running
if pgrep -f "wl-gammarelay-rs"; then
    pkill -f "wl-gammarelay-rs"
fi

# Start the watch process and get its PID
wl-gammarelay-rs watch {t} &
pid=$!

# Set the desired temperature
busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Temperature q "$1"

# Wait for the watch process to finish (bring back to fg)
wait $pid