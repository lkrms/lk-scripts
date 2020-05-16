#!/bin/bash
# shellcheck disable=SC1090,SC2046,SC2207

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"
. "$SCRIPT_DIR/bootstrap-packages.sh"

assert_not_root

# mark everything as a dependency
! EXPLICIT=($(pacman -Qeq)) ||
    [ "${#EXPLICIT[@]}" -eq "0" ] ||
    sudo pacman -D --asdeps "${EXPLICIT[@]}"

# mark (installed) bootstrap packages as explicitly installed
INSTALLED=($(comm -12 <(pacman -Qdq | sort | uniq) <(lk_echo_array "${PACMAN_PACKAGES[@]}" "${AUR_PACKAGES[@]}" | sort | uniq)))
[ "${#INSTALLED[@]}" -eq "0" ] ||
    sudo pacman -D --asexplicit "${INSTALLED[@]}"

MISSING_PAC=($(comm -13 <(pacman -Qeq | sort | uniq) <(lk_echo_array "${PACMAN_PACKAGES[@]}" | sort | uniq)))
MISSING_AUR=($(comm -13 <(pacman -Qeq | sort | uniq) <(lk_echo_array "${AUR_PACKAGES[@]}" | sort | uniq)))
MISSING=(${MISSING_PAC[@]+"${MISSING_PAC[@]}"} ${MISSING_AUR[@]+"${MISSING_AUR[@]}"})
[ "${#MISSING[@]}" -eq "0" ] ||
    ! get_confirmation "Install missing bootstrap packages?" ||
    {
        [ "${#MISSING_PAC[@]}" -eq "0" ] ||
            sudo pacman -Sy "${MISSING_PAC[@]}"

        [ "${#MISSING_AUR[@]}" -eq "0" ] ||
            { ! lk_command_exists yay && lk_warn "yay command missing"; } ||
            yay -Sy --aur "${MISSING_AUR[@]}"
    }
