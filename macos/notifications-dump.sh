#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

assert_is_macos
assert_not_root

DARWIN_USER_DIR="$(getconf DARWIN_USER_DIR)"
DB_PATH="$(dirname "$DARWIN_USER_DIR")"/"$(basename "$DARWIN_USER_DIR")/com.apple.notificationcenter/db2/db"

[ -f "$DB_PATH" ] || die "File doesn't exist: $DB_PATH"

DUMP_DIR="$TEMP_DIR/notifications/$(date_get_timestamp)"

mkdir -p "$DUMP_DIR"

DUMP_COUNT="$(
    sqlite3 "$DB_PATH" 'select writefile("'"$DUMP_DIR"'/" || r.rec_id || "-" || a.identifier || ".plist", data) from record r inner join app a on r.app_id = a.app_id where r.presented = 1' | wc -l | tr -d '[:space:]'
)"

plutil -convert xml1 "$DUMP_DIR"/*.plist

console_message "$DUMP_COUNT $(single_or_plural "$DUMP_COUNT" notification notifications) dumped to:" "$DUMP_DIR" "$BLUE"
