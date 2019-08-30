#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_command_exists xmodmap
assert_command_exists xdotool

# give it a second for keys to be (physically) released
has_argument "--no-sleep" || sleep 1

for KEYCODE in $(xmodmap -pm | grep -Pio '(?<=\b0x)[0-9a-f]+\b'); do

    echo -e "xdotool keyup $((16#$KEYCODE))\n" >&2
    xdotool keyup $((16#$KEYCODE))

done
