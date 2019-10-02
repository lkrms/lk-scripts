#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common-dev"

assert_command_exists git
assert_git_is_dir_working_repo

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

console_message "Checking remote branches..." "" "$CYAN"

ORIGIN_BRANCHES=($(
    # shellcheck disable=SC1090
    . "$SUBSHELL_SCRIPT_PATH" || exit
    git ls-remote --heads "$ORIGIN" | gnu_grep -Po '(?<=refs/heads/).*$' | sort
)) || die

UPSTREAM_BRANCHES=($(
    # shellcheck disable=SC1090
    . "$SUBSHELL_SCRIPT_PATH" || exit
    git ls-remote --heads "$UPSTREAM" | gnu_grep -Po '(?<=refs/heads/).*$' | sort
)) || die

LOCAL_BRANCHES=($(
    # shellcheck disable=SC1090
    . "$SUBSHELL_SCRIPT_PATH" || exit
    git for-each-ref --format='%(refname:short)' refs/heads/ | sort
)) || die

[ "${#UPSTREAM_BRANCHES[@]}" -gt "0" ] || die "No branches in remote \"$UPSTREAM\""
[ "${#LOCAL_BRANCHES[@]}" -gt "0" ] || die "No local branches"

MATCHING_BRANCHES=($(comm -12 <(printf '%s\n' "${LOCAL_BRANCHES[@]}") <(printf '%s\n' "${UPSTREAM_BRANCHES[@]}")))

if [ "${#MATCHING_BRANCHES[@]}" -gt "0" ]; then

    console_message "${#MATCHING_BRANCHES[@]} local $(single_or_plural "${#MATCHING_BRANCHES[@]}" "branch matches" "branches match") remote \"$UPSTREAM\":" "${MATCHING_BRANCHES[*]}" "$BOLD" "$MAGENTA"

    if get_confirmation "Track \"$UPSTREAM\" and push to \"$ORIGIN\" for the $(single_or_plural "${#MATCHING_BRANCHES[@]}" branch branches) listed above?" Y; then

        console_message "Configuring ${#MATCHING_BRANCHES[@]} local $(single_or_plural "${#MATCHING_BRANCHES[@]}" branch branches)..." "" "$BOLD" "$BLUE"

        for BRANCH in "${MATCHING_BRANCHES[@]}"; do

            git branch -u "${UPSTREAM}/${BRANCH}" "$BRANCH"
            git config "branch.${BRANCH}.pushRemote" "$ORIGIN"

        done

    fi

    echo

fi

MATCHING_BRANCHES=($(comm -23 <(printf '%s\n' "${LOCAL_BRANCHES[@]}") <(printf '%s\n' "${UPSTREAM_BRANCHES[@]}")))

if [ "${#MATCHING_BRANCHES[@]}" -gt "0" ]; then

    console_message "${#MATCHING_BRANCHES[@]} local $(single_or_plural "${#MATCHING_BRANCHES[@]}" "branch doesn't" "branches don't") exist in remote \"$UPSTREAM\":" "${MATCHING_BRANCHES[*]}" "$BOLD" "$MAGENTA"

    if get_confirmation "Track \"$ORIGIN\" for the $(single_or_plural "${#MATCHING_BRANCHES[@]}" branch branches) listed above?" Y; then

        console_message "Configuring ${#MATCHING_BRANCHES[@]} local $(single_or_plural "${#MATCHING_BRANCHES[@]}" branch branches)..." "" "$BOLD" "$BLUE"

        for BRANCH in "${MATCHING_BRANCHES[@]}"; do

            if array_search "$BRANCH" ORIGIN_BRANCHES >/dev/null; then

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
