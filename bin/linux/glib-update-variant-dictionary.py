#!/usr/bin/env python

import sys
from gi.repository import GLib

dict = GLib.VariantDict(GLib.Variant.parse(None, sys.argv[1], None, None))

key = sys.argv[2]
val = sys.argv[3]
valType = "s"

try:
    val = int(val)
    valType = "i"
except:
    pass

dict.insert_value(key, GLib.Variant(valType, val))

print(dict.end().print_(False))
