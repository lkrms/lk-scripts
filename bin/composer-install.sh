#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

assert_command_exists wget
assert_command_exists php

DELETE_ON_EXIT+=("$PWD/composer-setup.php")

EXPECTED_SIGNATURE="$(wget -qO - "https://composer.github.io/installer.sig")"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

[ "$EXPECTED_SIGNATURE" = "$ACTUAL_SIGNATURE" ] || die "Invalid installer signature"

php composer-setup.php "$@"
