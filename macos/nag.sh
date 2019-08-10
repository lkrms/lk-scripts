#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_is_macos
assert_not_root

assert_command_exists terminal-notifier

if [ "$#" -lt "1" ]; then

    echo "Usage: $(basename "$0") [title] [subtitle] [sound] [group_identifier] [scheme://url] [sender.app.bundle.id] [suppress if session inactive (Y/N)] [ignore Do Not Disturb (Y/N)] <message>"
    echo
    echo "Example: $(basename "$0") "'"Productivity Reminder" "" "Hero" "productivity_reminders" "todoist://today" "com.todoist.mac.Todoist" Y Y "Are you even working?"'

fi

TITLE=
SUBTITLE=
SOUND=
GROUP_ID=
OPEN_URL=
SENDER_ID=
ACTIVE_ONLY=N
IGNORE_DND=N

[ "$#" -gt "1" ] && TITLE="${1:-$TITLE}" && shift
[ "$#" -gt "1" ] && SUBTITLE="${1:-$SUBTITLE}" && shift
[ "$#" -gt "1" ] && SOUND="${1:-$SOUND}" && shift
[ "$#" -gt "1" ] && GROUP_ID="${1:-$GROUP_ID}" && shift
[ "$#" -gt "1" ] && OPEN_URL="${1:-$OPEN_URL}" && shift
[ "$#" -gt "1" ] && SENDER_ID="${1:-$SENDER_ID}" && shift
[ "$#" -gt "1" ] && ACTIVE_ONLY="${1:-$ACTIVE_ONLY}" && shift
[ "$#" -gt "1" ] && IGNORE_DND="${1:-$IGNORE_DND}" && shift

ARGUMENTS=()

[[ "$ACTIVE_ONLY" =~ ^[yY]$ ]] && "$SCRIPT_DIR/user-session-is-active.py" || exit

[ -n "$TITLE" ] && ARGUMENTS+=(-title "$TITLE")
[ -n "$SUBTITLE" ] && ARGUMENTS+=(-subtitle "$SUBTITLE")
[ -n "$SOUND" ] && ARGUMENTS+=(-sound "$SOUND")
[ -n "$GROUP_ID" ] && ARGUMENTS+=(-group "$GROUP_ID")
[ -n "$OPEN_URL" ] && ARGUMENTS+=(-open "$OPEN_URL")
[ -n "$SENDER_ID" ] && ARGUMENTS+=(-sender "$SENDER_ID")
[ -n "$IGNORE_DND" ] && ARGUMENTS+=(-ignoreDnD)
ARGUMENTS+=(-message "$*")

terminal-notifier "${ARGUMENTS[@]}"
