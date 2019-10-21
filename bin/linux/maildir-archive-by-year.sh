#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"

assert_root

DRYRUN_BY_DEFAULT=Y
dryrun_message

variable_exists "MAILDIRS" || MAILDIRS=(/home/*/Maildir)

[ "${#MAILDIRS[@]}" -gt "0" ] && are_directories "${MAILDIRS[@]}" || die "No Maildirs found"

FOLDER_PREFIX="INBOX"

for MAILDIR in "${MAILDIRS[@]}"; do

    ARCHIVE="$MAILDIR/.Archive/cur"

    [ -d "$ARCHIVE" ] || continue

    OWNER="$(gnu_stat -c '%U' "$MAILDIR")"
    SUBSCRIBED="$MAILDIR/courierimapsubscribed"
    YEAR="$(date '+%Y')"
    CONTINUE=1

    while [ "$CONTINUE" -ne "0" ]; do

        CONTINUE=0
        ((NEXT_YEAR = YEAR + 1))

        FOLDER="Archive.${YEAR}"
        TARGET_DIR="$MAILDIR/.${FOLDER}/cur"

        if [ ! -d "$TARGET_DIR" ]; then

            maybe_dryrun sudo -u "$OWNER" maildirmake -f "$FOLDER" "$MAILDIR" && {
                is_dryrun || [ -d "$TARGET_DIR" ]
            } || die "Unable to create folder $FOLDER in Maildir $MAILDIR"

            if [ -f "$SUBSCRIBED" ] && ! grep -Fxq "${FOLDER_PREFIX}.${FOLDER}" "$SUBSCRIBED"; then

                if ! is_dryrun; then

                    echo "${FOLDER_PREFIX}.${FOLDER}" >>"$SUBSCRIBED" || die "Unable to subscribe $OWNER to newly created folder $FOLDER in Maildir $MAILDIR"

                else

                    maybe_dryrun echo "${FOLDER_PREFIX}.${FOLDER}" ">>$SUBSCRIBED"

                fi

            fi

        fi

        maybe_dryrun find "$ARCHIVE" -type f -newermt "${YEAR}0101" -not -newermt "${NEXT_YEAR}0101" -exec mv -v '{}' "$TARGET_DIR" \;

        # set CONTINUE=1 if the archive contains email from a previous year
        CONTINUE="$(find "$ARCHIVE" -type f -not -newermt "${YEAR}0101" -print -quit | wc -l)"
        CONTINUE="${CONTINUE// /}"

        ((--YEAR))

    done

done
