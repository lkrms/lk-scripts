#!/bin/bash

SCRIPT_PATH="${BASH_SOURCE[0]}"
[ -h "$SCRIPT_PATH" ] && SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

. "$SCRIPT_DIR/../bash/common" || exit 1

assert_is_macos

argument_or_default PACKAGE_LIST_FILE "$SCRIPT_DIR/homebrew-packages"

if [ ! -f "$PACKAGE_LIST_FILE" ]; then

    echo "Usage: $(basename "$0") [/path/to/package_list_file]"
    exit 1

fi

REMOVE_LIST="$(comm -23 <(brew list -1 | sort) <(cat "$PACKAGE_LIST_FILE" | xargs -I {} bash -c "echo {}; brew deps --installed {}" | sort | uniq))" || exit 1

REMOVE_COUNT=$(echo -n "$REMOVE_LIST" | wc -l | sed -e 's/ //g')

if [ "$REMOVE_COUNT" -ne "0" ]; then

    NOUN=formula
    [ "$REMOVE_COUNT" -gt "1" ] && NOUN=formulae
    console_message "Found $REMOVE_COUNT $NOUN to uninstall" "" $BLUE
    echo "$REMOVE_LIST" | column
    echo

    if get_confirmation "Uninstall the $NOUN listed above?"; then

        console_message "Uninstalling $NOUN:" "$(echo $REMOVE_LIST)" $RED
        brew uninstall $REMOVE_LIST

    fi

else

    console_message "No formulae to uninstall" "" $GREEN

fi

