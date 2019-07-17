#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_is_macos
assert_not_root

DARWIN_USER_DIR="$(getconf DARWIN_USER_DIR)"
DB_PATH="$(dirname "$DARWIN_USER_DIR")"/"$(basename "$DARWIN_USER_DIR")/com.apple.notificationcenter/db2/db"

[ -f "$DB_PATH" ] || die "File doesn't exist: $DB_PATH"

DUMP_DIR="$RS_TEMP_DIR/notifications/$(date '+%s')"

mkdir -p "$DUMP_DIR"

DUMP_COUNT="$(
    set -euo pipefail
    sqlite3 "$DB_PATH" 'select writefile("'"$DUMP_DIR"'/" || r.rec_id || "-" || a.identifier || ".plist", data) from record r inner join app a on r.app_id = a.app_id where r.presented = 1' | wc -l | tr -d '[:space:]'
)"

plutil -convert xml1 "$DUMP_DIR"/*.plist

console_message "$DUMP_COUNT $(single_or_plural "$DUMP_COUNT" notification notifications) dumped to:" "$DUMP_DIR" "$BLUE"
