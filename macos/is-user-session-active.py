#!/usr/bin/python

import sys
import Quartz

d = Quartz.CGSessionCopyCurrentDictionary()

# we want to return 0, not 1, if a session is active
sys.exit(not (d and
              d.get("CGSSessionScreenIsLocked", 0) == 0 and
              d.get("kCGSSessionOnConsoleKey", 0) == 1))
