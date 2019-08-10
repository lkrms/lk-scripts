## To use `xrandr-auto.sh` for display configuration

Similar solutions (including the otherwise excellent [autorandr](https://github.com/phillipberndt/autorandr)) do not save `--dpi` or `--set "Broadcast RGB" "Full"`. Other utilities don't support scaling. I needed all three, so I wrote `xrandr-auto.sh`. Use it at your own risk.

1. Clone or download this repository to your system. Optionally, source the `.bashrc` file in your `~/.bashrc` or `~/.profile` file.
1. Run `xrandr-auto.sh` to generate `config/xrandr-suggested`. This is (re-)generated automatically if `config/xrandr` doesn't exist, or if you run `xrandr-auto.sh --suggest`.
1. Rename `xrandr-suggested` to `xrandr`, adjust, and test by running `xrandr-auto.sh`.
1. Add `/path/to/linux/xrandr-auto.sh --autostart` to your desktop environment's startup applications.
1. Bind a keyboard shortcut (e.g. Ctrl-Alt-Shift-R) to `/path/to/linux/xrandr-auto.sh` for easy resetting.
1. If your desktop environment uses LightDM, create `/etc/lightdm/lightdm.conf.d/xrandr.conf` as:
    [SeatDefaults]
    display-setup-script=/path/to/linux/xrandr-auto.sh
