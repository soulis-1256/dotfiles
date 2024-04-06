#!/bin/bash

wl-gammarelay-rs run &

# Wait until the process is running
while [[ $(busctl --user get-property rs.wl-gammarelay / rs.wl.gammarelay Temperature | awk '{print $2}') != 5000 ]]; do
    busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Temperature q 5000
    sleep 1
done