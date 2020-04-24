#!/bin/bash

# Disable wide-dhcpv6-client.service and add a symlink to this script
# in /etc/ppp/ip-up.d if needed.

[ -n "$PPP_IFACE" ] &&
    [ -d "/proc/sys/net/ipv6/conf/$PPP_IFACE" ] || exit 0

case "$(basename "$0")" in

*up*)
    echo 2 >"/proc/sys/net/ipv6/conf/$PPP_IFACE/accept_ra" || :
    # start /usr/sbin/dhcp6c if it's not already running
    [ -x "/etc/init.d/wide-dhcpv6-client" ] &&
        /etc/init.d/wide-dhcpv6-client status ||
        /etc/init.d/wide-dhcpv6-client start || :
    ;;

*down*)
    # nothing to do
    :
    ;;

esac
