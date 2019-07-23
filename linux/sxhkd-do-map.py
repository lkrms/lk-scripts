#!/usr/bin/env python3

import logging
import os
import re
import subprocess
import sys

log_directory = os.path.normpath(os.path.dirname(
    os.path.realpath(__file__)) + "/../log")
log_file = os.path.join(log_directory, "sxhkd-do-map.py.log")

if not os.path.exists(log_directory):
    os.makedirs(log_directory)
logging.basicConfig(
    filename=log_file, format="%(relativeCreated)s %(levelname)s: %(message)s", level=logging.INFO)

logging.info("keystroke in: {0}".format(sys.argv[1]))

window_id = subprocess.run(["xprop", "-root", "32x", "\n$0", "_NET_ACTIVE_WINDOW"],
                           stdout=subprocess.PIPE, check=True).stdout.decode().split("\n")[1]

logging.debug("window id: {0}".format(window_id))

window_class = ".".join([c.strip('"') for c in subprocess.run(['xprop', '-id', window_id, '8u',
                                                               '\n$0\n$1', 'WM_CLASS'], stdout=subprocess.PIPE, check=True).stdout.decode().split("\n")[1:]])

logging.info("window class: {0}".format(window_class))

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
original_key = key

is_alpha = re.search(r"^[a-z]$", key)
is_num = re.search(r"^[0-9]$", key)
is_command = in_super and not (in_ctrl or in_alt)
is_command_option = in_super and in_alt and not in_ctrl

key_command = ""
keyup_command = ""
done = False

if not skip:

    if is_terminal:

        # add shift for the expected result
        if is_command and original_key in ["c", "v", "n", "t", "w", "f", "a"]:
            out_shift = True

    if is_chrome:

        # developer tools
        if is_command_option and not in_shift and original_key == "i":
            key_command = "ctrl+shift+j"
            done = True

        # bookmarks manager
        if is_command_option and not in_shift and original_key == "b":
            key_command = "ctrl+shift+o"
            done = True

    # Command+Shift+Z -> Ctrl+Y
    if not done and is_command and in_shift and original_key == "z":
        out_shift = False
        key = "y"

if not done:
    if out_ctrl:
        key_command += "ctrl+"
    if out_alt:
        key_command += "alt+"
    if out_super:
        key_command += "super+"
    if out_shift:
        key_command += "shift+"
    key_command += key
    keyup_command += original_key

command = [
    "xdotool",
    "keyup", "--delay", "0", keyup_command,
    "key", "--delay", "0", "--clearmodifiers", key_command
]

if key_command != "":
    subprocess.run(command, check=True)

logging.info("xdotool command: {0}".format(command))
