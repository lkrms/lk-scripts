#!/bin/bash

# symlink in /etc/ppp/ip-up.d if needed

[ -n "$PPP_IFACE" ] &&
    [ -d "/proc/sys/net/ipv6/conf/$PPP_IFACE" ] || exit 0

case "$(basename "$0")" in

*up*)
    echo 2 >"/proc/sys/net/ipv6/conf/$PPP_IFACE/accept_ra" || :
    ;;

*down*)
    # nothing to do
    :
    ;;

esac
