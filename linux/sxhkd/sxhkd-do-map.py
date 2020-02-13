#!/usr/bin/env python3

import logging
import os
import re
import subprocess
import sys

xte_delay = "12000"
xdotool_delay = "12"


def make_xte_commands(command, keys, both_modifiers=False):

    xte_dictionary = {
        "ctrl": ["Control_L", "Control_R"],
        "alt": ["Alt_L", "Alt_R"],
        "super": ["Super_L", "Super_R"],
        "shift": ["Shift_L", "Shift_R"],
    }

    commands = []

    for key in keys:

        if key in xte_dictionary.keys():
            key_array = xte_dictionary[key] if both_modifiers else [
                xte_dictionary[key][0]]
        else:
            key_array = [key]

        for the_key in key_array:
            commands.append("{0} {1}".format(command, the_key))
            commands.append("usleep " + xte_delay)

    return commands


log_directory = os.path.normpath(os.path.dirname(
    os.path.realpath(__file__)) + "/../../log")
log_file = os.path.join(log_directory, "sxhkd-do-map.py.log")

if not os.path.exists(log_directory):
    os.makedirs(log_directory)
logging.basicConfig(
    filename=log_file, format="%(asctime)s %(relativeCreated)s %(levelname)s: %(message)s", level=logging.INFO)

logging.info("keystroke in: {0}".format(sys.argv[1]))

window_id = subprocess.run(["xprop", "-root", "32x", "\n$0", "_NET_ACTIVE_WINDOW"],
                           stdout=subprocess.PIPE, check=True).stdout.decode().split("\n")[1]

logging.debug("window id: {0}".format(window_id))

window_class = ".".join([c.strip('"') for c in subprocess.run(['xprop', '-id', window_id, '8u',
                                                               '\n$0\n$1', 'WM_CLASS'], stdout=subprocess.PIPE, check=True).stdout.decode().split("\n")[1:]])

logging.info("window class: {0}".format(window_class))

window_name = subprocess.run(['xprop', '-id', window_id, '8u',
                              '\n$0', 'WM_NAME'], stdout=subprocess.PIPE, check=True).stdout.decode().split("\n")[1].strip('"')

logging.info("window name: {0}".format(window_name))

is_unknown = window_class == "" and window_name == ""
is_chrome = bool(re.search(r"^google-chrome\.Google-chrome$", window_class))
is_terminal = bool(
    re.search(r"^(guake|io\.elementary\.terminal|tilix|xfce4-terminal)\.", window_class))
is_todoist = bool(re.search(
    r"^(todoist\.Todoist|crx_bgjohebimpjdhhocbknplfelpmdhifhd\.Google-chrome)$", window_class))
is_vscode = bool(re.search(r"^code\.Code$", window_class))

skip = is_unknown
quit_alt_f4 = is_chrome or is_todoist

args = sys.argv[1].split("+")

in_ctrl = "ctrl" in args
in_alt = "alt" in args
in_super = "super" in args
in_shift = "shift" in args

# make things macOS-like by default
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
mouse_button = re.sub(r"^button", "", key) if is_click else ""
is_command = in_super and not (in_ctrl or in_alt)
is_command_option = in_super and in_alt and not in_ctrl

keyup_pre_command = [] if is_click else [key]
key_command = []

mouseup_pre_command = mouse_button if is_click else ""
click_key_command = []
click_command = ""

key = "" if is_click else key

clear_modifiers = True
use_xte = False

done = False

if not skip:

    if is_terminal:

        # add shift for the expected result
        if is_command and original_key in ["c", "v", "n", "t", "w", "f", "a"]:
            out_shift = True

    if is_chrome:

        # developer tools
        if is_command_option and not in_shift and original_key == "i":
            key_command = ["ctrl", "shift", "j"]
            done = True

        # bookmarks manager
        if is_command_option and not in_shift and original_key == "b":
            key_command = ["ctrl", "shift", "o"]
            done = True

    if quit_alt_f4:

        if is_command and not in_shift and original_key == "q":
            key_command = ["alt", "F4"]
            done = True

    if not done:

        if is_command:

            # Command+Shift+Z -> Ctrl+Y
            if in_shift and original_key == "z":
                out_shift = False
                key = "y"

            if original_key == "g":
                done = True

                # "find next"
                if not in_shift:
                    key_command = ["F3"]

                # "find previous"
                else:
                    key_command = ["shift", "F3"]

if not done:
    if out_ctrl and (clear_modifiers or not in_ctrl):
        key_command.append("ctrl")
    if out_alt and (clear_modifiers or not in_alt):
        key_command.append("alt")
    if out_super and (clear_modifiers or not in_super):
        key_command.append("super")
    if out_shift and (clear_modifiers or not in_shift):
        key_command.append("shift")
    if key:
        key_command.append(key)
    if mouse_button:
        click_command = mouse_button
        click_key_command = key_command
        key_command = []

# xdotool's modifier handling is a bit broken
use_xte = use_xte or (clear_modifiers and (click_command or click_key_command))

command = ["xte"] if use_xte else ["xdotool"]

if use_xte:

    modifiers = []

    if clear_modifiers:
        if in_ctrl and not out_ctrl:
            modifiers.append("ctrl")
        if in_alt and not out_alt:
            modifiers.append("alt")
        if in_super and not out_super:
            modifiers.append("super")
        if in_shift and not out_shift:
            modifiers.append("shift")

    if keyup_pre_command:
        command.extend(make_xte_commands("keyup", keyup_pre_command, True))

    if mouseup_pre_command:
        command.extend(make_xte_commands("mouseup", [mouseup_pre_command]))

    command.extend(make_xte_commands("keyup", modifiers, True))

    if key_command:
        command.extend(make_xte_commands("key", key_command))

    if click_key_command:
        command.extend(make_xte_commands("keydown", click_key_command))

    if click_command:
        command.extend(make_xte_commands("mouseclick", [click_command]))

    if click_key_command:
        command.extend(make_xte_commands("keyup", click_key_command))

    command.extend(make_xte_commands("keydown", modifiers))

else:

    if keyup_pre_command:
        command.extend(["keyup", "--delay", xdotool_delay,
                        "+".join(keyup_pre_command)])

    if mouseup_pre_command:
        # unrecognized option '--delay'
        command.extend(["mouseup", mouseup_pre_command])

    if key_command:
        command.extend(["key", "--delay", xdotool_delay])
        if clear_modifiers:
            command.append("--clearmodifiers")
        command.append("+".join(key_command))

    if click_key_command:
        command.extend(["keydown", "--delay", xdotool_delay,
                        "+".join(click_key_command)])

    if click_command:
        command.extend(
            ["click", "--delay", xdotool_delay, "+".join(click_command)])

    if click_key_command:
        command.extend(["keyup", "--delay", xdotool_delay,
                        "+".join(click_key_command)])

if len(command) > 1:
    subprocess.run(command, check=True)
    logging.info("command: {0}".format(command))
else:
    logging.info("no command run")
