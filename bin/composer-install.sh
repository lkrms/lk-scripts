#!/bin/bash
# shellcheck disable=SC1090

include='' . lk-bash-load.sh || exit

lk_assert_command_exists wget
lk_assert_command_exists php

lk_delete_on_exit "$PWD/composer-setup.php"

EXPECTED_SIGNATURE="$(wget -qO - "https://composer.github.io/installer.sig")"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

[ "$EXPECTED_SIGNATURE" = "$ACTUAL_SIGNATURE" ] || lk_die "Invalid installer signature"

php composer-setup.php "$@"
