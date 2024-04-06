#!/bin/bash

network_status=$(nmcli -t -f NAME,DEVICE,TYPE connection show --active | grep -E '(ethernet|wireless)')

if [[ -n $network_status ]]; then
    name=$(echo "$network_status" | cut -d: -f1)
    device=$(echo "$network_status" | cut -d: -f2)
    type=$(echo $network_status | awk -F: '{print $3 ~ /wireless/}')

    if [[ $1 == "type" ]]; then
        if [[ $type -eq 1 ]]; then
            # wifi
            signal_strength=$(nmcli -t -f SIGNAL,ACTIVE device wifi | awk -F: '{if ($2 == "yes") print $1}')
            if $signal_strength -lt 25; then
                echo "󰤟 "
            elif $signal_strength -lt 50; then
                echo "󰤢 "
            elif $signal_strength -lt 85; then
                echo "󰤥 "
            else
                echo "󰤨 "
            fi
        elif [[ $type -eq 0 ]]; then
            echo "󰈀 "
        fi
    elif [[ $1 == "info" ]]; then
        if [[ $type -eq 1 ]]; then
            printf "SSID: $name \nDevice: $device"
        elif [[ $type -eq 0 ]]; then
            printf "Device: $device"
        fi
    fi
else
    echo "󰣼 "
fi
