#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"
. "$SCRIPT_DIR/../bash/common-git"

assert_command_exists git
assert_git_dir_is_working_repo

USAGE="Usage: $(basename "$0") [upstream.repo.url]"

[ "$#" -le "1" ] || die "$USAGE"

ORIGIN="${GIT_ORIGIN_REMOTE_NAME:-origin}"
UPSTREAM="${GIT_UPSTREAM_REMOTE_NAME:-upstream}"

git_has_remote "$ORIGIN" || die "No remote named \"$ORIGIN\""

if [ "$#" -eq "1" ]; then

    if git_has_remote "$UPSTREAM"; then

        git remote set-url "$UPSTREAM" "$1"

    else

        git remote add "$UPSTREAM" "$1"

    fi

else

    git_has_remote "$UPSTREAM" || die "No remote named \"$UPSTREAM\". $USAGE"

fi

git config push.default current

lk_console_message "Checking remote branches..."

ORIGIN_BRANCHES=($(
    git ls-remote --heads "$ORIGIN" | gnu_grep -Po '(?<=refs/heads/).*$' | sort
)) || die

UPSTREAM_BRANCHES=($(
    git ls-remote --heads "$UPSTREAM" | gnu_grep -Po '(?<=refs/heads/).*$' | sort
)) || die

LOCAL_BRANCHES=($(
    git for-each-ref --format='%(refname:short)' refs/heads/ | sort
)) || die

[ "${#UPSTREAM_BRANCHES[@]}" -gt "0" ] || die "No branches in remote \"$UPSTREAM\""
[ "${#LOCAL_BRANCHES[@]}" -gt "0" ] || die "No local branches"

MATCHING_BRANCHES=($(comm -12 <(printf '%s\n' "${LOCAL_BRANCHES[@]}") <(printf '%s\n' "${UPSTREAM_BRANCHES[@]}")))

if [ "${#MATCHING_BRANCHES[@]}" -gt "0" ]; then

    lk_echo_array "${MATCHING_BRANCHES[@]}" | lk_console_list "${#MATCHING_BRANCHES[@]} local $(single_or_plural "${#MATCHING_BRANCHES[@]}" "branch matches" "branches match") remote \"$UPSTREAM\":" "$BOLD$MAGENTA"

    if get_confirmation "Track \"$UPSTREAM\" and push to \"$ORIGIN\" for the $(single_or_plural "${#MATCHING_BRANCHES[@]}" branch branches) listed above?" Y; then

        # unfetched remote branches can't be tracked
        lk_console_message "Fetching from remotes \"$ORIGIN\" and \"$UPSTREAM\"..."
        git fetch --multiple --quiet "$UPSTREAM" "$ORIGIN"

        lk_console_message "Configuring ${#MATCHING_BRANCHES[@]} local $(single_or_plural "${#MATCHING_BRANCHES[@]}" branch branches)..." "$BOLD$BLUE"

        for BRANCH in "${MATCHING_BRANCHES[@]}"; do

            git branch -u "${UPSTREAM}/${BRANCH}" "$BRANCH"
            git config "branch.${BRANCH}.pushRemote" "$ORIGIN"

        done

    fi

    echo

fi

MATCHING_BRANCHES=($(comm -23 <(printf '%s\n' "${LOCAL_BRANCHES[@]}") <(printf '%s\n' "${UPSTREAM_BRANCHES[@]}")))

if [ "${#MATCHING_BRANCHES[@]}" -gt "0" ]; then

    lk_echo_array "${MATCHING_BRANCHES[@]}" | lk_console_list "${#MATCHING_BRANCHES[@]} local $(single_or_plural "${#MATCHING_BRANCHES[@]}" "branch doesn't" "branches don't") exist in remote \"$UPSTREAM\":" "$BOLD$MAGENTA"

    if get_confirmation "Track \"$ORIGIN\" for the $(single_or_plural "${#MATCHING_BRANCHES[@]}" branch branches) listed above?" Y; then

        lk_console_message "Configuring ${#MATCHING_BRANCHES[@]} local $(single_or_plural "${#MATCHING_BRANCHES[@]}" branch branches)..." "$BOLD$BLUE"

        for BRANCH in "${MATCHING_BRANCHES[@]}"; do

            if in_array "$BRANCH" ORIGIN_BRANCHES; then

                git branch -u "${ORIGIN}/${BRANCH}" "$BRANCH"

            else

                git push -u "$ORIGIN" "${BRANCH}:${BRANCH}"

            fi

            git config --unset "branch.${BRANCH}.pushRemote" || true

        done

    fi

    echo

fi

# ensure any future upstream checkouts push to origin
git config "remote.pushDefault" "$ORIGIN"
