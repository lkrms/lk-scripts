#!/bin/bash

MAKE_PERMANENT=0

if [ "$1" = "--permanently" ]; then

    MAKE_PERMANENT=1
    shift

fi

"/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" --disable-gpu "$@" || exit

if [ "$MAKE_PERMANENT" -eq "1" ]; then

    PLIST="/Applications/Visual Studio Code.app/Contents/Info.plist"

    [ -w "$PLIST" ] || exit

    SCRIPT_PATH="${BASH_SOURCE[0]}"
    [ -L "$SCRIPT_PATH" ] && SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    SCRIPT_NAME="$(basename "$SCRIPT_PATH")"
    EXECUTABLE="/Applications/Visual Studio Code.app/Contents/MacOS/$SCRIPT_NAME"

    if [ ! -L "$EXECUTABLE" ]; then

        SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

        # just in case it exists but isn't a symbolic link
        rm -f "$EXECUTABLE"

        ln -s "$SCRIPT_DIR/$SCRIPT_NAME" "$EXECUTABLE" && {

            if [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")" != "$SCRIPT_NAME" ]; then

                /usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable "'"$SCRIPT_NAME"'"' "$PLIST"

            fi

        }

    fi

fi

