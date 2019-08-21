#!/usr/bin/env python3

import atexit
import dbus
import os
import re
import signal
import subprocess
import sys

assert "XDG_SESSION_ID" in os.environ, "Error: XDG_SESSION_ID not set"

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

        line = p.stdout.readline()

        if line:

            if re.match(r'LOCK\b', line):

                i.Lock()

            elif re.match(r'UNBLANK\b', line):

                i.Unlock()

except KeyboardInterrupt:

    sys.exit(signal.SIGINT)
