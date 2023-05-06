#!/bin/bash

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 path"
  exit 1
fi

path=$1

if [[ ! -d $path ]]; then
  echo "Error: '$path' is not a directory"
  exit 1
fi

# Use fzf to search for a file inside the path
selected_file=$(find "$path" -type f 2>/dev/null | fzf)

if [[ -z "$selected_file" ]]; then
  echo "No file selected"
  exit 1
fi

# Open the selected file in Vim
vimx "$selected_file"
