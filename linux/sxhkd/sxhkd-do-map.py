#!/usr/bin/env python3

import logging
import os
import re
import subprocess
import sys

log_directory = os.path.normpath(os.path.dirname(
    os.path.realpath(__file__)) + "/../../log")
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
is_dbeaver = bool(re.search(r"^DBeaver\.DBeaver$", window_class))
is_terminal = bool(
    re.search(r"^(io\.elementary\.terminal|tilix|guake)\.", window_class))
is_todoist = bool(re.search(r"^todoist\.Todoist$", window_class))
is_vscode = bool(re.search(r"^code\.Code$", window_class))

skip = is_unknown
quit_alt_f4 = is_chrome or is_dbeaver or is_todoist

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
is_click = re.search(r"^button[0-9]+$", key)
is_command = in_super and not (in_ctrl or in_alt)
is_command_option = in_super and in_alt and not in_ctrl

keyup_pre_command = []
key_command = []
mouseup_pre_command = []
click_key_command = []
click_command = []
clear_modifiers_manually = False
done = False

if not skip:

    if is_terminal:

        # add shift for the expected result
        if is_command and original_key in ["c", "v", "n", "t", "w", "f", "a"]:
            out_shift = True

    if is_chrome:

        # developer tools
        if is_command_option and not in_shift and original_key == "i":
            keyup_pre_command = [original_key]
            key_command = ["ctrl", "shift", "j"]
            done = True

        # bookmarks manager
        if is_command_option and not in_shift and original_key == "b":
            keyup_pre_command = [original_key]
            key_command = ["ctrl", "shift", "o"]
            done = True

    if is_click:

        click_command = [re.sub(r"^button", "", original_key)]
        mouseup_pre_command = click_command
        clear_modifiers_manually = True
        key = ""

    if quit_alt_f4:

        if is_command and not in_shift and original_key == "q":
            keyup_pre_command = [original_key]
            key_command = ["alt", "F4"]
            done = True

    # Command+Shift+Z -> Ctrl+Y
    if not done and is_command and in_shift and original_key == "z":
        out_shift = False
        key = "y"

if not done:
    if out_ctrl and (not clear_modifiers_manually or not in_ctrl):
        key_command.append("ctrl")
    if out_alt and (not clear_modifiers_manually or not in_alt):
        key_command.append("alt")
    if out_super and (not clear_modifiers_manually or not in_super):
        key_command.append("super")
    if out_shift and (not clear_modifiers_manually or not in_shift):
        key_command.append("shift")
    if key:
        keyup_pre_command.append(original_key)
        key_command.append(key)
    if click_command:
        click_key_command = key_command
        key_command = []

modifiers = []
command = ["xdotool"]

if keyup_pre_command:
    command.extend(["keyup", "--delay", "0", "+".join(keyup_pre_command)])

if mouseup_pre_command:
    command.extend(["mouseup", "+".join(mouseup_pre_command)])

if clear_modifiers_manually:
    if in_ctrl and not out_ctrl:
        modifiers.append("ctrl")
    if in_alt and not out_alt:
        modifiers.append("alt")
    if in_super and not out_super:
        modifiers.append("super")
    if in_shift and not out_shift:
        modifiers.append("shift")
    command.extend(["keyup", "--delay", "0", "+".join(modifiers)])

if key_command:
    command.extend(["key", "--delay", "0"])
    if not clear_modifiers_manually:
        command.append("--clearmodifiers")
    command.append("+".join(key_command))

if click_key_command:
    command.extend(["keydown", "--delay", "0", "+".join(click_key_command)])

if click_command:
    command.extend(["click", "--delay", "0", "+".join(click_command)])

if click_key_command:
    command.extend(["keyup", "--delay", "0", "+".join(click_key_command)])

if clear_modifiers_manually:
    command.extend(["keydown", "--delay", "0", "+".join(modifiers)])

if len(command) > 1:
    subprocess.run(command, check=True)

logging.info("xdotool command: {0}".format(command))
