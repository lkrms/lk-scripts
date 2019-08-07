#!/bin/bash

set -euo pipefail

if [ "$#" -ne "1" ] || [ ! -f "$1" ]; then

    echo "Usage: $(basename "$0") </path/to/icon.png>" >&2
    exit 1

fi

SIZES=(
    16x16
    24x24
    32x32
    48x48
    64x64
    96x96
    128x128
    256x256
    512x512
    1024x1024
)

for SIZE in "${SIZES[@]}"; do

    mkdir -p "$HOME/.local/share/icons/hicolor/$SIZE/apps"

    convert "$1" -resize "$SIZE" "$HOME/.local/share/icons/hicolor/$SIZE/apps/$(basename "$1")"

done

if command -v gtk-update-icon-cache >/dev/null 2>&1; then

    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor"

fi
