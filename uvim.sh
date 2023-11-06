#!/bin/bash

if [[ $# -ne 1 ]]; then
  echo "Missing path argument"
  exit 1
fi

path=$1

if [[ ! -d $path ]]; then
  echo "Error: '$path' is not a directory"
  exit 1
fi

# Check if fzf is installed
if ! command -v fzf &>/dev/null; then
  echo "Error: 'fzf' is not installed. Please install it before using this script."
  exit 1
fi

# Use fzf to search for a file inside the path
selected_file=$(find "$path" -type f 2>/dev/null | fzf --preview "cat {}")

if [[ -z "$selected_file" ]]; then
  echo "No file selected"
  exit 1
fi

# Check if the file is write-protected
if [[ -w "$selected_file" ]]; then
  nvim "$selected_file"
else
  sudoedit "$selected_file"
fi