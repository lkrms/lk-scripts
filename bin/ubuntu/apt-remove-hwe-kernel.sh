#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"
. "$SCRIPT_DIR/../bash/common-apt"

lk_assert_is_ubuntu
lk_assert_not_root

apt_mark_cache_clean

if apt_package_installed "linux-generic-hwe-$DISTRIB_RELEASE" && lk_confirm "Ubuntu LTS enablement package ${BOLD}linux-generic-hwe-${DISTRIB_RELEASE}${RESET} is currently installed. Remove it and any related kernel packages?" N; then

    apt_remove_packages "linux-generic-hwe-$DISTRIB_RELEASE" "linux-image-generic-hwe-$DISTRIB_RELEASE" "linux-headers-generic-hwe-$DISTRIB_RELEASE"

    apt_install_packages "kernel" "linux-generic" N

    apt_process_queue

fi

CURRENT_KERNEL=($(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances linux-generic | grep -E '^linux-image-[-.0-9]+-generic$'))

if [ "${#CURRENT_KERNEL[@]}" -eq "1" ] && apt_package_installed "${CURRENT_KERNEL[0]}"; then

    CURRENT_KERNEL_VERSION="$(dpkg-query -f '${Version}\n' -W "${CURRENT_KERNEL[0]}")"

    OTHER_KERNEL_PACKAGES=()

    IFS=$'\t'

    while IFS= read -r LINE; do

        PACKAGE=($LINE)

        if dpkg --compare-versions "${PACKAGE[1]}" gt "$CURRENT_KERNEL_VERSION"; then

            OTHER_KERNEL_PACKAGES+=("${PACKAGE[0]}")

        fi

    done < <(dpkg-query -f '${binary:Package}\t${Version}\t${db:Status-Status}\n' -W "linux-image-*-generic" "linux-modules-*-generic" "linux-headers-*" | grep $'\tinstalled$' | cut -d $'\t' -f1-2 | grep -v $'^linux-headers-generic\t')

    unset IFS

    if [ "${#OTHER_KERNEL_PACKAGES[@]}" -gt "0" ]; then

        lk_console_item "Most recent kernel provided by the ${BOLD}linux-generic${RESET} package:" "$CURRENT_KERNEL_VERSION"

        lk_echo_array "${OTHER_KERNEL_PACKAGES[@]}" | lk_console_list "${#OTHER_KERNEL_PACKAGES[@]} kernel $(lk_maybe_plural "${#OTHER_KERNEL_PACKAGES[@]}" package packages) to delete:" "$BOLD$YELLOW"

        if lk_confirm "Delete the kernel $(lk_maybe_plural "${#OTHER_KERNEL_PACKAGES[@]}" package packages) listed above?" N; then

            sudo debconf-set-selections <<EOF
linux-base linux-base/removing-running-kernel boolean false
EOF

            sudo DEBIAN_FRONTEND=noninteractive apt-get "${APT_GET_OPTIONS[@]}" remove "${OTHER_KERNEL_PACKAGES[@]}"

        fi

    fi

else

    lk_console_message "Unable to identify most recent kernel provided by the ${BOLD}linux-generic${RESET} package" "$LK_BOLD$LK_RED"

fi

apt_purge --no-y
