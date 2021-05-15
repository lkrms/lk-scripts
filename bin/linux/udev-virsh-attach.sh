#!/bin/bash

# Add entries like the following to `/etc/udev/rules.d/90-virsh-attach.rules`:
#
# ACTION=="add",    SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="04b8", ENV{ID_MODEL_ID}=="0155", RUN+="/path/to/udev-virsh-attach.sh vm_name"
# ACTION=="remove", SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="04b8", ENV{ID_MODEL_ID}=="0155", RUN+="/path/to/udev-virsh-attach.sh vm_name"
#
# Use `udevadm monitor --property --udev` while attaching and detaching a
# device to check its properties. Then `udevadm control --reload`, followed by
# `udevadm trigger --action=add` if needed.
#
# If not working as expected, try `udevadm test /sys/DEVPATH` (find the current
# DEVPATH using `udevadm monitor --property --udev`).

[ -n "$ID_VENDOR_ID" ] &&
    [ -n "$ID_MODEL_ID" ] &&
    [ -n "$ACTION" ] &&
    [ -n "${1-}" ] || exit

export VIRSH_DOMAIN="$1"
OUT_FILE="/tmp/$(basename "$0").out"
ERR_FILE="/tmp/$(basename "$0").err"
SCRIPT_FILE="/tmp/$(basename "$0")_${ID_VENDOR_ID}_${ID_MODEL_ID}.sh"

# shellcheck disable=SC2094
function log_start() {
    {
        echo -e "\n-- START $ACTION $ID_SERIAL $(date +'%b %_d %H:%M:%S.%N %z') --" | tee -a /dev/stderr
        printenv >&2
    } >>"$OUT_FILE" 2>>"$ERR_FILE"
}

[ -x "$SCRIPT_FILE" ] || {
    cat >"$SCRIPT_FILE" <<SCRIPT
#!/bin/bash
{
    virsh "\$VIRSH_COMMAND" "\$VIRSH_DOMAIN" /dev/stdin <<EOF
<hostdev mode='subsystem' type='usb'>
  <source>
    <vendor id='0x$ID_VENDOR_ID'/>
    <product id='0x$ID_MODEL_ID'/>
  </source>
</hostdev>
EOF
    echo "-- END $ACTION $ID_SERIAL $(date +'%b %_d %H:%M:%S.%N %z') --" | tee -a /dev/stderr
} >>"$OUT_FILE" 2>>"$ERR_FILE"
SCRIPT
    chmod a+x "$SCRIPT_FILE"
}

case "$ACTION" in

add)
    export VIRSH_COMMAND="attach-device"
    log_start

    # allow a couple of seconds for the device to be ready to attach
    printf '%s\n' "sleep 2" "$SCRIPT_FILE" | at -M now
    ;;

remove)
    export VIRSH_COMMAND="detach-device"
    log_start

    # detach the device immediately
    "$SCRIPT_FILE"
    ;;

*)
    echo "Unexpected action '$ACTION'" >"$ERR_FILE"
    exit 1
    ;;

esac
