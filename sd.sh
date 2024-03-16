#!/bin/bash

if [[ $# -ne 1 ]]; then
  echo "Missing path argument"
  return 1
fi

path="$1"

if [[ ! -d "$path" ]]; then
  echo "$path is not a valid directory"
  return 1
fi

# Check if fzf is installed
if ! command -v fzf &>/dev/null; then
  echo "Error: 'fzf' is not installed. Please install it before using this script."
  return 1
fi

target_dir="$(find "$path" -type d 2>/dev/null | fzf)"
if [[ -n "$target_dir" ]]; then
  cd "$target_dir"
fi