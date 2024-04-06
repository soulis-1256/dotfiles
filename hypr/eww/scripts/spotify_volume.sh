#!/bin/bash

if test $1 == "up"; then
	playerctl --player spotify volume 0.01+
elif test $1 == "down"; then
	playerctl --player spotify volume 0.01-
fi

eww update music_volume=$(playerctl --player spotify volume | awk '{printf "%.0f", $1 * 100}')
