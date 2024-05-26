#!/bin/bash

function clamp {
	min=$1
	max=$2
	val=$3
	python -c "print(max($min, min($val, $max)))"
}

direction=$1
current=$2
monitor=$3

monitor_min_limit=$(if test "$monitor" = "1"; then echo 1; else echo 6; fi)
monitor_max_limit=$(if test "$monitor" = "1"; then echo 5; else echo 10; fi)

if test "$direction" = "up"; then
	target=$(clamp $monitor_min_limit $monitor_max_limit $(($current + 1)))
	echo "jumping to $target"
	hyprctl dispatch workspace $target
elif test "$direction" = "down"; then
	target=$(clamp $monitor_min_limit $monitor_max_limit $(($current - 1)))
	echo "jumping to $target"
	hyprctl dispatch workspace $target
fi
