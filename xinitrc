#!/bin/sh

if LK_SCRIPT_PATH="$(realpath "$0" 2>/dev/null)" ||
    LK_SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "$0")"; then
    LK_ROOT="$(dirname "$LK_SCRIPT_PATH")"
    export LK_ROOT
    unset LK_SCRIPT_PATH
    eval "$("$LK_ROOT/lk_get_shell_env.sh")"
    eval "$(xrandr-auto.sh --get-shell-env --autostart)" || true
fi

xset -b
xset s 120 60

export XSECURELOCK_PASSWORD_PROMPT="emoticon"
export XSECURELOCK_SAVER="saver_blank"
export XSECURELOCK_SHOW_DATETIME=1
xss-lock -n /usr/lib/xsecurelock/dimmer -l -- xsecurelock &

xfconf-query -c xfce4-session -p /general/LockCommand -n -t string -s "xset s activate"

. /etc/xdg/xfce4/xinitrc
