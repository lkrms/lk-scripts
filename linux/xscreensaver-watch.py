#!/usr/bin/env python3

"""
Because ``xscreensaver`` doesn't emit ``dbus`` signals, applications that
rely on them for session lock/unlock notifications (e.g. KeePassXC) don't work
correctly. To emit ``org.freedesktop.login1.Session.Lock`` and
``org.freedesktop.login1.Session.Unlock`` signals based on ``xscreensaver``'s
state changes, add this script to your autostart, or create a systemd service
for it.
"""

import atexit
import dbus
import os
import re
import signal
import subprocess
import sys

assert "XDG_SESSION_ID" in os.environ, \
    "Error: environment variable XDG_SESSION_ID is not set"

bus = dbus.SystemBus()
o = bus.get_object("org.freedesktop.login1",
                   "/org/freedesktop/login1/session/{}".format(os.getenv("XDG_SESSION_ID")))
i = dbus.Interface(o, "org.freedesktop.login1.Session")

p = subprocess.Popen(["xscreensaver-command", "-watch"],
                     stdout=subprocess.PIPE,
                     stderr=subprocess.STDOUT)

atexit.register(p.terminate)

try:

    while p.poll() is None:

        line = str(p.stdout.readline())

        if re.match(r'LOCK\b', line):

            i.Lock()

        elif re.match(r'UNBLANK\b', line):

            i.Unlock()

except KeyboardInterrupt:

    sys.exit(signal.SIGINT)
