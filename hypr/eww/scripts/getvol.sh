#!/bin/bash

wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk -F': ' '{print $2 * 100}' 
