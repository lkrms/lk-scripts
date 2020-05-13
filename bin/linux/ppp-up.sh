#!/bin/bash

# Disable wide-dhcpv6-client.service and add a symlink to this script
# in /etc/ppp/ip-up.d if needed.

[ -n "$PPP_IFACE" ] &&
    [ -d "/proc/sys/net/ipv6/conf/$PPP_IFACE" ] || exit 0

case "$(basename "$0")" in

*up*)
    echo 2 >"/proc/sys/net/ipv6/conf/$PPP_IFACE/accept_ra" || :
    # [re]start /usr/sbin/dhcp6c
    if [ -x "/etc/init.d/wide-dhcpv6-client" ]; then
        /etc/init.d/wide-dhcpv6-client status &&
            /etc/init.d/wide-dhcpv6-client stop || :
        /etc/init.d/wide-dhcpv6-client start || :
    fi
    # start traffic shaping (see https://github.com/tohojo/sqm-scripts)
    if [ -x "/usr/bin/sqm" ] &&
        [ -f "/etc/sqm/sqm.conf" ]; then
        . "/etc/sqm/sqm.conf"
        if [ -n "$SQM_STATE_DIR" ]; then
            [ -e "$SQM_STATE_DIR/$PPP_IFACE.state" ] &&
                /usr/bin/sqm reload "$PPP_IFACE" ||
                /usr/bin/sqm start "$PPP_IFACE" || :
        fi
    fi
    ;;

*down*)
    # stop traffic shaping
    if [ -x "/usr/bin/sqm" ] &&
        [ -f "/etc/sqm/sqm.conf" ]; then
        . "/etc/sqm/sqm.conf"
        if [ -n "$SQM_STATE_DIR" ]; then
            [ ! -e "$SQM_STATE_DIR/$PPP_IFACE.state" ] ||
                /usr/bin/sqm stop "$PPP_IFACE" || :
        fi
    fi
    ;;

esac
