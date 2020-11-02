#!/bin/bash
# shellcheck disable=SC1090,SC2034

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"
. "$SCRIPT_DIR/../bash/common-git"

lk_is_declared "GIT_URL_REPLACEMENTS" || GIT_URL_REPLACEMENTS=()
GIT_LOG_LIMIT="${GIT_LOG_LIMIT:-14}"

lk_assert_command_exists git

# don't support anything before Debian "jessie"
assert_git_version_at_least 2.1.4

lk_mapfile <(git_get_code_roots "$@") CODE_ROOTS

# shellcheck disable=SC2153
[ "${#CODE_ROOTS[@]}" -gt "0" ] || lk_die "Usage: $(basename "$0") [/code/root...]"

# allow this script to be changed while it's running
{

    case "$(basename "$0")" in

    *check*)
        DO_FETCH=0
        DO_PUSH=0
        DO_MERGE=0
        MAIN_VERB="Checking"
        COMPLETION_VERB="checked"
        ;;

    *push*)
        DO_FETCH=0
        DO_PUSH=1
        DO_MERGE=0
        MAIN_VERB="Checking"
        COMPLETION_VERB="checked"
        ;;

    *)
        DO_FETCH=1
        DO_PUSH=1
        DO_MERGE=1
        MAIN_VERB="Updating"
        COMPLETION_VERB="updated"
        ;;

    esac

    REPO_ROOTS=()
    REPO_NAMES=()
    REPO_LONG_NAMES=()
    WARNINGS_FILES=()
    REPO_COUNT=0
    UPDATED_REPOS=()
    PUSHED_REPOS=()

    for CODE_ROOT in "${CODE_ROOTS[@]}"; do

        while IFS= read -rd $'\0' REPO_ROOT; do

            REPO_ROOT="$(realpath "$REPO_ROOT")"

            git_is_dir_working_root "$REPO_ROOT" || continue

            REPO_ROOTS+=("$REPO_ROOT")

            ((++REPO_COUNT))

            REPO_NAME="${REPO_ROOT#$CODE_ROOT}"
            REPO_NAME="${REPO_NAME#/}"
            REPO_LONG_NAME="${CODE_ROOT}/${LK_BOLD}${REPO_NAME}${LK_RESET}"
            [ -n "$REPO_NAME" ] || {
                REPO_NAME="$REPO_ROOT"
                REPO_LONG_NAME="${LK_BOLD}${REPO_NAME}${LK_RESET}"
            }
            REPO_NAMES+=("$REPO_NAME")
            REPO_LONG_NAMES+=("$REPO_LONG_NAME")

            WARNINGS_FILE="$(lk_mktemp_file)"
            lk_delete_on_exit "$WARNINGS_FILE"
            WARNINGS_FILES+=("$WARNINGS_FILE")

        done < <(

            find "$CODE_ROOT" -type d -exec test -d '{}/.git' \; -prune -print0 | sort -z

        )

    done

    [ "${#REPO_ROOTS[@]}" -gt "0" ] || lk_die "No repositories found"

    if [ "$DO_FETCH" -eq "1" ]; then

        lk_console_message "Fetching from all remotes in ${REPO_COUNT} $(lk_maybe_plural "$REPO_COUNT" repository repositories)" "$LK_BOLD$LK_MAGENTA"

        for i in "${!REPO_ROOTS[@]}"; do

            REPO_ROOT="${REPO_ROOTS[$i]}"
            WARNINGS_FILE="${WARNINGS_FILES[$i]}"

            (

                pushd "$REPO_ROOT" >/dev/null || lk_die

                IFS=$'\n' read -d '' -ra REPO_REMOTES < <(git remote) || true

                if [ "${#REPO_REMOTES[@]}" -gt "0" ]; then

                    if [ "${#GIT_URL_REPLACEMENTS[@]}" -gt "0" ] && [ -f ".git/config" ]; then

                        SED_ARGS=()
                        for REGEX in "${GIT_URL_REPLACEMENTS[@]}"; do
                            SED_ARGS+=(-e "$REGEX")
                        done
                        lk_maybe_sed "${SED_ARGS[@]}" ".git/config"

                    fi

                    for REMOTE in "${REPO_REMOTES[@]}"; do

                        git fetch --prune --quiet "$REMOTE" || echo "Can't fetch from remote ${LK_BOLD}${REMOTE}${LK_RESET}" >>"$WARNINGS_FILE"

                    done

                fi

            ) &

        done

        wait

        echo

    fi

    for i in "${!REPO_ROOTS[@]}"; do

        REPO_ROOT="${REPO_ROOTS[$i]}"
        REPO_NAME="${REPO_NAMES[$i]}"
        REPO_LONG_NAME="${REPO_LONG_NAMES[$i]}"
        WARNINGS_FILE="${WARNINGS_FILES[$i]}"

        pushd "$REPO_ROOT" >/dev/null || lk_die

        lk_console_item "$MAIN_VERB repository:" "${REPO_LONG_NAME}" "$LK_CYAN"

        git update-index --refresh -q >/dev/null || true

        IFS=$'\n' read -d '' -ra REPO_REMOTES < <(git remote) || true

        if [ "${#REPO_REMOTES[@]}" -gt "0" ]; then

            UPDATED_BRANCHES=()
            PUSHED_BRANCHES=()

            while IFS= read -u 4 -rd $'\0' REF_CODE; do

                eval "$REF_CODE"

                UPSTREAM="$(git rev-parse --symbolic-full-name "$BRANCH"'@{upstream}' 2>/dev/null)" || UPSTREAM=
                PUSH="$(git rev-parse --symbolic-full-name "$BRANCH"'@{push}' 2>/dev/null)" || PUSH="$UPSTREAM"
                UPSTREAM="${UPSTREAM#refs/remotes/}"
                PUSH="${PUSH#refs/remotes/}"
                PUSH_REMOTE="${PUSH%%/*}"

                BEHIND_UPSTREAM=0
                AHEAD_PUSH=0
                PRETTY_BRANCH="$(git_format_branch "$BRANCH" "$BEHIND_UPSTREAM" "$AHEAD_PUSH")"

                if [ -n "$UPSTREAM" ]; then

                    UPSTREAM_COMMIT="$(git rev-parse --verify "$UPSTREAM")"
                    BEHIND_UPSTREAM="$(git rev-list --count "${LOCAL_COMMIT}..${UPSTREAM_COMMIT}")"

                    if [ "$BEHIND_UPSTREAM" -gt "0" ]; then

                        PRETTY_BRANCH="$(git_format_branch "$BRANCH" "$BEHIND_UPSTREAM" "$AHEAD_PUSH")"

                        if [ "$DO_MERGE" -eq "1" ]; then

                            if [ "$IS_CURRENT_BRANCH" = '*' ]; then

                                lk_console_item "Attempting to merge upstream $(lk_maybe_plural "$BEHIND_UPSTREAM" commit commits) (fast-forward only):" "$PRETTY_BRANCH" "$LK_GREEN"
                                git merge --ff-only "$UPSTREAM" && UPDATED_BRANCHES+=("$PRETTY_BRANCH") && BEHIND_UPSTREAM=0 || echo "Can't merge upstream $(lk_maybe_plural "$BEHIND_UPSTREAM" commit commits) into branch $PRETTY_BRANCH" >>"$WARNINGS_FILE"

                            else

                                lk_console_item "Attempting to fast-forward branch from upstream:" "$PRETTY_BRANCH" "$LK_GREEN"
                                git fetch . "$UPSTREAM":"$BRANCH" && UPDATED_BRANCHES+=("$PRETTY_BRANCH") && BEHIND_UPSTREAM=0 || echo "Can't merge upstream $(lk_maybe_plural "$BEHIND_UPSTREAM" commit commits) into branch $PRETTY_BRANCH" >>"$WARNINGS_FILE"

                            fi

                        else

                            echo "Upstream $(lk_maybe_plural "$BEHIND_UPSTREAM" commit commits) to merge into branch $PRETTY_BRANCH" >>"$WARNINGS_FILE"

                        fi

                        [ "$BEHIND_UPSTREAM" -gt "0" ] || PRETTY_BRANCH="$(git_format_branch "$BRANCH" "$BEHIND_UPSTREAM" "$AHEAD_PUSH")"

                    fi

                else

                    echo "Branch $PRETTY_BRANCH doesn't have an \"upstream\" remote-tracking branch" >>"$WARNINGS_FILE"

                fi

                if [ -n "$PUSH" ]; then

                    PUSH_COMMIT="$(git rev-parse --verify "$PUSH")"
                    AHEAD_PUSH="$(git rev-list --count "${PUSH_COMMIT}..${LOCAL_COMMIT}")"
                    BEHIND_PUSH="$BEHIND_UPSTREAM"

                    if [ "$AHEAD_PUSH" -gt "0" ]; then

                        PRETTY_BRANCH="$(git_format_branch "$BRANCH" "$BEHIND_PUSH" "$AHEAD_PUSH")"

                        if [ "$BEHIND_PUSH" -gt "0" ]; then

                            echo "Can't push $(lk_maybe_plural "$AHEAD_PUSH" commit commits) to branch $PRETTY_BRANCH until upstream $(lk_maybe_plural "$BEHIND_PUSH" "commit is" "commits are") resolved" >>"$WARNINGS_FILE"

                        else

                            echo
                            lk_console_message "${LK_BOLD}${AHEAD_PUSH} $(lk_maybe_plural "$AHEAD_PUSH" commit commits) to branch \"${BRANCH}\" in \"${REPO_NAME}\" $(lk_maybe_plural "$AHEAD_PUSH" "hasn't" "haven't") been pushed:${LK_RESET}" "$LK_BOLD$LK_YELLOW"
                            echo
                            echo "${LK_WRAP_OFF}$(git log "-$GIT_LOG_LIMIT" --oneline --decorate --color=always "${PUSH_COMMIT}..${LOCAL_COMMIT}")${LK_WRAP}"

                            if [ "$AHEAD_PUSH" -gt "$GIT_LOG_LIMIT" ]; then

                                ((NOT_SHOWN = AHEAD_PUSH - GIT_LOG_LIMIT))

                                echo
                                echo "($NOT_SHOWN $(lk_maybe_plural "$NOT_SHOWN" commit commits) not shown)"

                            fi

                            if [ "$DO_PUSH" -eq "1" ] && echo && lk_confirm "Attempt to push branch \"$BRANCH\" to remote \"$PUSH_REMOTE\"?" Y; then

                                git push --tags "$PUSH_REMOTE" "$BRANCH:$BRANCH" && PUSHED_BRANCHES+=("$PRETTY_BRANCH") && AHEAD_PUSH=0 || echo "Can't push $(lk_maybe_plural "$AHEAD_PUSH" commit commits) to branch $PRETTY_BRANCH" >>"$WARNINGS_FILE"

                            else

                                echo "Unpushed $(lk_maybe_plural "$AHEAD_PUSH" commit commits) to branch $PRETTY_BRANCH" >>"$WARNINGS_FILE"

                            fi

                        fi

                    fi

                else

                    echo "Branch $PRETTY_BRANCH doesn't have a \"push\" remote-tracking branch" >>"$WARNINGS_FILE"

                fi

            done 4< <(

                git for-each-ref --format='
BRANCH="%(refname:short)"
LOCAL_COMMIT="%(objectname:short)"
IS_CURRENT_BRANCH="%(HEAD)"
%00' refs/heads/

            )

            if [ "${#UPDATED_BRANCHES[@]}" -gt "0" ]; then

                UPDATED_REPOS+=("${REPO_LONG_NAME}($(lk_implode ', ' "${UPDATED_BRANCHES[@]}"))")

            fi

            if [ "${#PUSHED_BRANCHES[@]}" -gt "0" ]; then

                PUSHED_REPOS+=("${REPO_LONG_NAME}($(lk_implode ', ' "${PUSHED_BRANCHES[@]}"))")

            fi

        else

            echo "No remotes in repository" >>"$WARNINGS_FILE"

        fi

        CHANGES=()

        UNTRACKED="$(git ls-files --other --exclude-standard)" || lk_die
        [ -z "$UNTRACKED" ] || CHANGES+=("untracked")

        git diff-files --quiet || CHANGES+=("unstaged")

        git diff-index --cached --quiet HEAD || CHANGES+=("uncommitted")

        if [ "${#CHANGES[@]}" -gt "0" ]; then

            echo "$(lk_upper_first "$(lk_implode "/" "${CHANGES[@]}")") changes" >>"$WARNINGS_FILE"

        fi

        if git rev-parse --verify -q refs/stash >/dev/null; then

            STASH_COUNT="$(git rev-list --walk-reflogs --count refs/stash)"

            echo "$STASH_COUNT $(lk_maybe_plural "$STASH_COUNT" stash stashes)" >>"$WARNINGS_FILE"

        fi

        GIT_FILEMODE="$(git config core.fileMode 2>/dev/null)" || true
        GIT_IGNORECASE="$(git config core.ignoreCase 2>/dev/null)" || true
        GIT_PRECOMPOSEUNICODE="$(git config core.precomposeUnicode 2>/dev/null)" || true

        if lk_is_wsl; then

            [ "$GIT_FILEMODE" = "false" ] || { git config --bool core.fileMode "false" && lk_echoc "Git option disabled: core.fileMode" "$LK_BOLD" "$LK_YELLOW"; } || lk_die

        else

            [ -z "$GIT_FILEMODE" ] || [ "$GIT_FILEMODE" = "true" ] || { git config --bool core.fileMode "true" && lk_echoc "Git option enabled: core.fileMode" "$LK_BOLD" "$LK_YELLOW"; } || lk_die

        fi

        # TODO: check filesystem case-sensitivity rather than assuming macOS and Windows are case-insensitive
        if lk_is_linux; then

            [ -z "$GIT_IGNORECASE" ] || [ "$GIT_IGNORECASE" = "false" ] || { git config --bool core.ignoreCase "false" && lk_echoc "Git option disabled: core.ignoreCase" "$LK_BOLD" "$LK_YELLOW"; } || lk_die

        else

            [ "$GIT_IGNORECASE" = "true" ] || { git config --bool core.ignoreCase "true" && lk_echoc "Git option enabled: core.ignoreCase" "$LK_BOLD" "$LK_YELLOW"; } || lk_die

        fi

        if lk_is_macos; then

            [ "$GIT_PRECOMPOSEUNICODE" = "true" ] || { git config --bool core.precomposeUnicode "true" && lk_echoc "Git option enabled: core.precomposeUnicode" "$LK_BOLD" "$LK_YELLOW"; } || lk_die

        else

            [ -z "$GIT_PRECOMPOSEUNICODE" ] || [ "$GIT_PRECOMPOSEUNICODE" = "false" ] || { git config --bool core.precomposeUnicode "false" && lk_echoc "Git option disabled: core.precomposeUnicode" "$LK_BOLD" "$LK_YELLOW"; } || lk_die

        fi

        popd >/dev/null

        echo

    done

    lk_echoc "All done. ${REPO_COUNT} $(lk_maybe_plural "$REPO_COUNT" repository repositories) ${COMPLETION_VERB}." "$LK_BOLD"
    echo

    if [ "${#UPDATED_REPOS[@]}" -gt "0" ]; then

        lk_echoc "${#UPDATED_REPOS[@]} $(lk_maybe_plural "${#UPDATED_REPOS[@]}" repository repositories) fast-forwarded from upstream:" "$LK_BOLD" "$LK_GREEN"
        printf '%s\n' "${UPDATED_REPOS[@]}" ""

    fi

    if [ "${#PUSHED_REPOS[@]}" -gt "0" ]; then

        lk_echoc "${#PUSHED_REPOS[@]} $(lk_maybe_plural "${#PUSHED_REPOS[@]}" repository repositories) pushed upstream:" "$LK_BOLD" "$LK_GREEN"
        printf '%s\n' "${PUSHED_REPOS[@]}" ""

    fi

    DIRTY_REPO_COUNT=0

    for i in "${!REPO_ROOTS[@]}"; do

        lk_mapfile "${WARNINGS_FILES[$i]}" FILE_TO_ARRAY

        if [ "${#FILE_TO_ARRAY[@]}" -gt "0" ]; then

            lk_console_item "${LK_BOLD}${LK_RED}${#FILE_TO_ARRAY[@]} $(lk_maybe_plural "${#FILE_TO_ARRAY[@]}" "issue requires" "issues require") attention in:${LK_RESET}" "${REPO_LONG_NAMES[$i]}" "$LK_RED"
            printf -- '- [ ] %s\n' "${FILE_TO_ARRAY[@]}"
            echo

            ((++DIRTY_REPO_COUNT))

        fi

    done

    [ "$DIRTY_REPO_COUNT" -gt "0" ] || {
        lk_console_message "No issues found" "$LK_BOLD$LK_RED"
        echo
    }

    exit

}
