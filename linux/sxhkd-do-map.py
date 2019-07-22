#!/usr/bin/env python3

import re
import subprocess
import sys

window_id = subprocess.run(["xprop", "-root", "32x", "\n$0", "_NET_ACTIVE_WINDOW"],
                           stdout=subprocess.PIPE, check=True).stdout.decode().split("\n")[1]
window_class = ".".join([c.strip('"') for c in subprocess.run(['xprop', '-id', window_id, '8u',
                                                               '\n$0\n$1', 'WM_CLASS'], stdout=subprocess.PIPE, check=True).stdout.decode().split("\n")[1:]])

is_unknown = window_class == ""
is_chrome = bool(re.search(r"^google-chrome\.Google-chrome$", window_class))
is_vscode = bool(re.search(r"^code\.Code$", window_class))
is_terminal = bool(
    re.search(r"^(io\.elementary\.terminal|tilix|guake)\.", window_class))

skip = is_unknown

args = sys.argv[1].split("+")

in_ctrl = "ctrl" in args
in_alt = "alt" in args
in_super = "super" in args
in_shift = "shift" in args

if not skip:
    out_ctrl = in_super
    out_alt = in_alt
    out_super = False
    out_shift = in_shift
else:
    out_ctrl = in_ctrl
    out_alt = in_alt
    out_super = in_super
    out_shift = in_shift

key = args[-1]

is_alpha = re.search(r"^[a-z]$", key)
is_num = re.search(r"^[0-9]$", key)
is_command = in_super and not (in_ctrl or in_alt)
is_command_option = in_super and in_alt and not in_ctrl

ret = ""
done = False

if not skip:

    if is_terminal:

        # add shift for the expected result
        if is_command and key in ["c", "v", "n", "t", "w", "f", "a"]:
            out_shift = True

    if is_chrome:

        # developer tools
        if is_command_option and not in_shift and key == "i":
            ret = "ctrl+shift+j"
            done = True

        # bookmarks manager
        if is_command_option and not in_shift and key == "b":
            ret = "ctrl+shift+o"
            done = True

    # Command+Shift+Z -> Ctrl+Y
    if not done and is_command and in_shift and key == "z":
        out_shift = False
        key = "y"

if not done:
    if out_ctrl:
        ret += "ctrl+"
    if out_alt:
        ret += "alt+"
    if out_super:
        ret += "super+"
    if out_shift:
        ret += "shift+"
    ret += key

if ret != "":
    subprocess.run(["xdotool", "keyup", "--delay", "0", key,
                    "key", "--delay", "0", "--clearmodifiers", ret], check=True)
