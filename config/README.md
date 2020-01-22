# config

Various scripts look for configuration files in this folder.

To override, for example, `npm-packages-default`, copy it to `npm-packages` and adjust as needed.

## natural-scroll-devices

Natural scrolling is applied to each `slave pointer` line in the output of `xinput list`, as long as it matches at least one regex in `natural-scroll-devices`.

The default behaviour, established by a wildcard regex in `natural-scroll-devices-default`, is to enable natural scrolling on all pointer devices. To override this, create an empty `natural-scroll-devices` file to disable natural scrolling, or to limit it to particular pointers, create a `natural-scroll-devices` file with one or more patterns, for example:

    # generic devices
    Bluetooth Mouse
    USB Optical Mouse

    # branded mice and touchpads
    Logitech.*Mouse
    Microsoft.*Mouse
    Synaptics TouchPad

    # specific models
    Logitech M705

Pattern matching is case-sensitive and relies on `grep -E`.

