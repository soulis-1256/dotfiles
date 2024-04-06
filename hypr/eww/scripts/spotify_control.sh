#!/bin/bash

playerctl --player spotify play-pause

eww update music_status=$(playerctl --player spotify status)
