#!/bin/bash

# Check if another instance of the script is running
LOCK_FILE="/tmp/screen_brightness_lock"
if [ -e "$LOCK_FILE" ] && kill -0 "$(cat "$LOCK_FILE")"; then
    echo "Script is already running. Exiting."
    exit 1
fi

# Create lock file with flock
LOCK_FD=200
exec {LOCK_FD}>"$LOCK_FILE"
if ! flock -n "$LOCK_FD"; then
    echo "Failed to acquire lock. Another instance is already running. Exiting."
    exit 1
fi

# Function to increase or decrease brightness
change_brightness() {
    ddcutil setvcp 10 "$1" "$2"
}

# Check for the correct number of arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <+/- value>"
    rm "$LOCK_FILE"
    exit 1
fi

# Parse arguments
sign=$1
value=$2

# Validate sign argument
if [ "$sign" != "+" ] && [ "$sign" != "-" ]; then
    echo "Invalid sign argument. Use '+' to increase or '-' to decrease brightness."
    rm "$LOCK_FILE"
    exit 1
fi

# Validate value argument
if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "Invalid value argument. Please provide a numeric value."
    rm "$LOCK_FILE"
    exit 1
fi

# Call the function to change brightness
change_brightness "$sign" "$value"

# Remove lock file
exec {LOCK_FD}>&-

pkill -SIGRTMIN+10 waybar