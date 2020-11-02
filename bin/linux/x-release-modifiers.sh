#!/bin/bash
# shellcheck disable=SC1090

include='' . lk-bash-load.sh || exit

lk_assert_command_exists xmodmap
lk_assert_command_exists xdotool

# give it a second for keys to be (physically) released
lk_has_arg "--no-sleep" || sleep 1

for KEYCODE in $(xmodmap -pm | grep -Pio '(?<=\b0x)[0-9a-f]+\b'); do

    echo -e "xdotool keyup $((16#$KEYCODE))\n" >&2
    xdotool keyup $((16#$KEYCODE))

done
