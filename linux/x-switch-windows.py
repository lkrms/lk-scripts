#!/usr/bin/env python
# sourced from: https://gist.github.com/tysonholub/c737d562614aa0d83add66dbec378723

from subprocess import Popen, PIPE, call
import logging
import sys
import os

# NOTE: this script assumes a debian system and requires the wmctrl and xdotool packages
#   sudo apt-get install wmctrl xdotool

# NOTE: To get [Alt + ` ]to register on Elementary OS requires removing the keybinding via dconf editor for switch-group/switch-group-backward
#   org.gnome.desktop.wm.keybindings.switch-group: []
#   org.gnome.desktop.wm.keybindings.switch-group-backward: []
# set custom hotkey for forward/backward window group scrolling (switch-group)
#   python /path/to/x-switch-windows.py group -f
#   python /path/to/x-switch-windows.py group -b
# set custom hotkey for forward/backward window scrolling (switch-windows)
#   python /path/to/x-switch-windows.py window -f
#   python /path/to/x-switch-windows.py window -b

# logging will be placed into
#   log/x-switch-windows.py.log

log_directory = os.path.normpath(os.path.dirname(
    os.path.realpath(__file__)) + '/../log')
log_file = os.path.join(log_directory, 'x-switch-windows.py.log')

if not os.path.exists(log_directory):
    os.makedirs(log_directory)
logging.basicConfig(
    filename=log_file, format='%(relativeCreated)s %(levelname)s (%(pathname)s:%(lineno)d): %(message)s', level=logging.DEBUG)

logging.info('Args: {0}'.format(sys.argv))
logging.info('looking for windows')

if 'group' in sys.argv:
    method = 'group'
else:
    method = 'window'

if '-b' in sys.argv:
    direction = '-b'
else:
    direction = '-f'

IGNORE_CLASS = [
    'plank.Plank',
    'wingpanel.Wingpanel'
]

try:
    windows = []
    for line in Popen("wmctrl -lx", shell=True, stdout=PIPE).stdout.read().split('\n'):
        win = line.split()
        if win and int(win[1]) > -1 and win[2] not in IGNORE_CLASS:
            # wine apps might have an unusual class like "notepad++.exe.notepad++.exe"
            # ultimately we would want this _class to resolve to "notepad++.exe"
            _class = win[2].split('.')
            windows.append(dict(
                id=int(win[0], 16),
                desktop=int(win[1]),
                _class='.'.join(_class[(len(_class) / 2):])
            ))
    logging.info('windows found: {0}'.format(windows))

    current_window_id = int(
        Popen("xdotool getactivewindow", shell=True, stdout=PIPE).stdout.read().strip())
    logging.info('current_window_id: {0}'.format(current_window_id))
    current_window_class = next(
        (x['_class'] for x in windows if x['id'] == current_window_id), None)
    current_window_desktop = next(
        (x['desktop'] for x in windows if x['id'] == current_window_id), None)

    if current_window_class and method == 'group':
        class_windows = [x for x in windows if x['_class'] ==
                         current_window_class and x['desktop'] == current_window_desktop]
        logging.info('Class windows: {0}'.format(class_windows))
        if class_windows:
            if direction == '-f':
                index = 0
                for x in xrange(len(class_windows)):
                    if class_windows[x]['id'] == current_window_id:
                        index = x
                        logging.info('Found window index: {0}'.format(index))
                        break
                if index + 1 >= len(class_windows):
                    index = 0
                else:
                    index = index + 1
            elif direction == '-b':
                index = len(class_windows) - 1
                for x in xrange(len(class_windows) - 1, -1, -1):
                    if class_windows[x]['id'] == current_window_id:
                        index = x
                        logging.info('Found window index: {0}'.format(index))
                        break
                if index <= 0:
                    index = len(class_windows) - 1
                else:
                    index = index - 1
            logging.info('Calling class window index {0}'.format(index))
            call(['wmctrl', '-i', '-a', str(class_windows[index]['id'])])
        else:
            logging.info('class_windows not found')
    elif method == 'window':
        desktop_windows = [
            x for x in windows if x['desktop'] == current_window_desktop]
        if desktop_windows:
            if direction == '-f':
                index = 0
                for x in xrange(len(desktop_windows)):
                    if desktop_windows[x]['id'] == current_window_id:
                        index = x
                        logging.info('Found window index: {0}'.format(index))
                        break
                if index + 1 >= len(desktop_windows):
                    index = 0
                else:
                    index = index + 1
            elif direction == '-b':
                index = len(desktop_windows) - 1
                for x in xrange(len(desktop_windows) - 1, -1, -1):
                    if desktop_windows[x]['id'] == current_window_id:
                        index = x
                        logging.info('Found window index: {0}'.format(index))
                        break
                if index <= 0:
                    index = len(desktop_windows) - 1
                else:
                    index = index - 1
            logging.info('Calling window {0}'.format(desktop_windows[index]))
            call(['wmctrl', '-i', '-a', str(desktop_windows[index]['id'])])
        else:
            logging.info('windows not found')
    else:
        logging.info('current_window_class not found')

except Exception as e:
    logging.exception("x-switch-windows.py blew up")
