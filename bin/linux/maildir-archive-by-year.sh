#!/bin/bash

for ARCHIVE in /home/*/Maildir/.Archive/cur; do

	MAILDIR="${ARCHIVE%/.Archive/cur}"
	OWNER="$(stat -c '%U' "$MAILDIR")"
	YEAR="$(date '+%Y')"
	CONTINUE=1

	while [ "$CONTINUE" -eq "1" ]; do

		CONTINUE=0

		(( NEXT_YEAR = YEAR + 1 ))

		[ -d "$MAILDIR/.Archive.$YEAR/cur/" ] || sudo -u "$OWNER" maildirmake -f "Archive.${YEAR}" "$MAILDIR" || exit 1

		[ -d "$MAILDIR/.Archive.$YEAR/cur/" ] || exit 1

		find "$ARCHIVE" -type f -newermt "${YEAR}0101" -not -newermt "${NEXT_YEAR}0101" -exec mv -v '{}' "$MAILDIR/.Archive.$YEAR/cur/" \;

	done

done
