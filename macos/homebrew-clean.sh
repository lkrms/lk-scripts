#!/bin/bash
# shellcheck disable=SC1090,SC2207

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

assert_is_macos
assert_command_exists brew

# necessary to prevent errors when substituting empty arrays ("${EMPTY_ARRAY[@]}" throws an "unbound variable" error on macOS)
set +u

USAGE="Usage: $(basename "$0") [/path/to/formula_list_file...] [formula...]"

# get a list of all available formulae
AVAILABLE_PACKAGES=($(
    . "$SUBSHELL_SCRIPT_PATH" || exit
    brew search | sort | uniq
))

# and all currently installed formulae
CURRENT_PACKAGES=($(
    . "$SUBSHELL_SCRIPT_PATH" || exit
    brew list -1 --full-name | sort | uniq
))

# load formulae we consider "safe"
SAFE_PACKAGES=()
MAIN_LIST_FILE="$SCRIPT_DIR/homebrew-formulae"
LIST_FILES=("$MAIN_LIST_FILE")

while [ "$#" -gt "0" ] && [ -f "${1:-}" ]; do

    LIST_FILES+=("$1")
    shift

done

for f in "${LIST_FILES[@]}"; do

    PACKAGES=($(
        . "$SUBSHELL_SCRIPT_PATH" || exit
        sort <"$f" | uniq
    ))

    BAD_PACKAGES=($(comm -23 <(printf '%s\n' "${PACKAGES[@]}") <(printf '%s\n' "${AVAILABLE_PACKAGES[@]}")))

    if [ "${#BAD_PACKAGES[@]}" -gt "0" ]; then

        console_message "Invalid $(single_or_plural "${#BAD_PACKAGES[@]}" formula formulae) found in $f:" "${BAD_PACKAGES[*]}" "$BOLD" "$RED" >&2

        if [ "$f" = "$MAIN_LIST_FILE" ]; then

            SAFE_PACKAGES+=($(comm -12 <(printf '%s\n' "${PACKAGES[@]}") <(printf '%s\n' "${AVAILABLE_PACKAGES[@]}")))
            continue

        fi

        die "$USAGE"

    fi

    SAFE_PACKAGES+=("${PACKAGES[@]}")

done

if [ "$#" -gt "0" ]; then

    PACKAGES=($(printf '%s\n' "$@" | sort | uniq))
    BAD_PACKAGES=($(comm -23 <(printf '%s\n' "${PACKAGES[@]}") <(printf '%s\n' "${AVAILABLE_PACKAGES[@]}")))

    if [ "${#BAD_PACKAGES[@]}" -gt "0" ]; then

        console_message "Invalid $(single_or_plural "${#BAD_PACKAGES[@]}" formula formulae):" "${BAD_PACKAGES[*]}" "$BOLD" "$RED" >&2
        die "$USAGE"

    fi

    SAFE_PACKAGES+=("${PACKAGES[@]}")

fi

SAFE_PACKAGES=($(printf '%s\n' "${SAFE_PACKAGES[@]}" | sort | uniq))

# remove any formulae that aren't actually installed
SAFE_PACKAGES=($(comm -12 <(printf '%s\n' "${SAFE_PACKAGES[@]}") <(printf '%s\n' "${CURRENT_PACKAGES[@]}")))

# add dependencies (repeatedly, because Homebrew has recursion bugs)
SAFE_PACKAGE_COUNT=-1
while [ "${#SAFE_PACKAGES[@]}" -ne "$SAFE_PACKAGE_COUNT" ]; do

    SAFE_PACKAGE_COUNT="${#SAFE_PACKAGES[@]}"

    SAFE_PACKAGES+=($(brew deps --union --installed "${SAFE_PACKAGES[@]}"))
    SAFE_PACKAGES=($(printf '%s\n' "${SAFE_PACKAGES[@]}" | sort | uniq))

done

REMOVE_LIST=($(comm -23 <(printf '%s\n' "${CURRENT_PACKAGES[@]}") <(printf '%s\n' "${SAFE_PACKAGES[@]}")))

if [ "${#REMOVE_LIST[@]}" -gt "0" ]; then

    NOUN="$(single_or_plural "${#REMOVE_LIST[@]}" formula formulae)"

    console_message "Found ${#REMOVE_LIST[@]} $NOUN to uninstall:" "" "$BOLD" "$MAGENTA"
    echo "${REMOVE_LIST[@]}" | column

    if get_confirmation "Uninstall the $NOUN listed above?" Y Y; then

        console_message "Uninstalling $NOUN..." "" "$GREEN"
        brew uninstall "${REMOVE_LIST[@]}"

    fi

else

    console_message "No formulae to uninstall" "" "$GREEN"

fi
