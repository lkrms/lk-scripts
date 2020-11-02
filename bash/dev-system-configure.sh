#!/bin/bash
# shellcheck disable=SC1090,SC2119

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/common"
. "$SCRIPT_DIR/common-dev"

lk_assert_not_root

dev_install_packages

dev_apply_system_config
