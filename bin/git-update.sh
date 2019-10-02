#!/bin/bash
# shellcheck disable=SC2034

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common-dev"

assert_command_exists git

# no support for anything before Debian "jessie"
assert_git_version_is_at_least 2.1.4

git_get_code_roots

# shellcheck disable=SC2153
[ "${#CODE_ROOTS[@]}" -gt "0" ] || die "Usage: $(basename "$0") [/code/root...]"

GIT_LOG_LIMIT="${GIT_LOG_LIMIT:-14}"

case "$(basename "$0")" in

*check*)
    DO_FETCH=0
    DO_PUSH=0
    MAIN_VERB="Checking"
    COMPLETION_VERB="checked"
    ;;

*push*)
    DO_FETCH=0
    DO_PUSH=1
    MAIN_VERB="Checking"
    COMPLETION_VERB="checked"
    ;;

*)
    DO_FETCH=1
    DO_PUSH=1
    MAIN_VERB="Updating"
    COMPLETION_VERB="updated"
    ;;

esac

REPO_ROOTS=()
REPO_NAMES=()
REPO_LONG_NAMES=()
REPO_COUNT=0
UPDATED_REPOS=()
PUSHED_REPOS=()
WARNINGS=()

for CODE_ROOT in "${CODE_ROOTS[@]}"; do

    while IFS= read -rd $'\0' REPO_ROOT; do

        REPO_ROOT="$(realpath "$REPO_ROOT")"

        git_is_dir_working_root "$REPO_ROOT" || continue

        REPO_ROOTS+=("$REPO_ROOT")

        ((++REPO_COUNT))

        REPO_NAME="${REPO_ROOT#$CODE_ROOT}"
        REPO_NAME="${REPO_NAME#/}"
        REPO_LONG_NAME="${CODE_ROOT}/${BOLD}${REPO_NAME}${RESET}"
        [ -n "$REPO_NAME" ] || {
            REPO_NAME="$REPO_ROOT"
            REPO_LONG_NAME="${BOLD}${REPO_NAME}${RESET}"
        }
        REPO_NAMES+=("$REPO_NAME")
        REPO_LONG_NAMES+=("$REPO_LONG_NAME")

    done < <(

        # shellcheck disable=SC1090
        . "$SUBSHELL_SCRIPT_PATH" || exit

        # within each CODE_ROOT, sort by depth then name
        for i in $(seq 0 "${DEFAULT_CODE_REPO_DEPTH:-2}"); do

            find "$CODE_ROOT" -mindepth "$i" -maxdepth "$i" -type d -print0 | sort -z

        done

    )

done

[ "${#REPO_ROOTS[@]}" -gt "0" ] || die "No repositories found"

if [ "$DO_FETCH" -eq "1" ]; then

    console_message "Fetching from all remotes in ${REPO_COUNT} $(single_or_plural "$REPO_COUNT" repository repositories):" "${REPO_LONG_NAMES[*]}" "$MAGENTA"

    WARNINGS_FILE="$(create_temp_file N)"
    DELETE_ON_EXIT+=("$WARNINGS_FILE")

    for i in "${!REPO_ROOTS[@]}"; do

        REPO_ROOT="${REPO_ROOTS[$i]}"
        REPO_LONG_NAME="${REPO_LONG_NAMES[$i]}"

        (

            # shellcheck disable=SC1090
            . "$SUBSHELL_SCRIPT_PATH" || exit

            pushd "$REPO_ROOT" >/dev/null || die

            IFS=$'\n'
            REPO_REMOTES=($(git remote))
            unset IFS

            if [ "${#REPO_REMOTES[@]}" -gt "0" ]; then

                for REMOTE in "${REPO_REMOTES[@]}"; do

                    git fetch --prune --quiet "$REMOTE" || echo "Can't fetch from remote ${BOLD}${REMOTE}${RESET} in $REPO_LONG_NAME" >>"$WARNINGS_FILE"

                done

            fi

        ) &

    done

    wait

    echo

    file_to_array "$WARNINGS_FILE" ""

    if [ "${#FILE_TO_ARRAY[@]}" -gt "0" ]; then

        WARNINGS+=("${FILE_TO_ARRAY[@]}")

    fi

fi

for i in "${!REPO_ROOTS[@]}"; do

    REPO_ROOT="${REPO_ROOTS[$i]}"
    REPO_NAME="${REPO_NAMES[$i]}"
    REPO_LONG_NAME="${REPO_LONG_NAMES[$i]}"

    pushd "$REPO_ROOT" >/dev/null || die

    console_message "$MAIN_VERB repository:" "${REPO_LONG_NAME}" "$CYAN"

    IFS=$'\n'
    REPO_REMOTES=($(git remote))
    unset IFS

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

                    if [ "$IS_CURRENT_BRANCH" = '*' ]; then

                        console_message "Attempting to merge upstream $(single_or_plural "$BEHIND_UPSTREAM" commit commits) (fast-forward only):" "$PRETTY_BRANCH" "$GREEN"
                        git merge --ff-only "$UPSTREAM" && UPDATED_BRANCHES+=("$PRETTY_BRANCH") && BEHIND_UPSTREAM=0 || WARNINGS+=("Can't merge upstream $(single_or_plural "$BEHIND_UPSTREAM" commit commits) into branch $PRETTY_BRANCH in $REPO_LONG_NAME")

                    else

                        console_message "Attempting to fast-forward branch from upstream:" "$PRETTY_BRANCH" "$GREEN"
                        git fetch . "$UPSTREAM":"$BRANCH" && UPDATED_BRANCHES+=("$PRETTY_BRANCH") && BEHIND_UPSTREAM=0 || WARNINGS+=("Can't merge upstream $(single_or_plural "$BEHIND_UPSTREAM" commit commits) into branch $PRETTY_BRANCH in $REPO_LONG_NAME")

                    fi

                    [ "$BEHIND_UPSTREAM" -gt "0" ] || PRETTY_BRANCH="$(git_format_branch "$BRANCH" "$BEHIND_UPSTREAM" "$AHEAD_PUSH")"

                fi

            else

                WARNINGS+=("Branch $PRETTY_BRANCH in $REPO_LONG_NAME doesn't have an \"upstream\" remote-tracking branch")

            fi

            if [ -n "$PUSH" ]; then

                # TODO: fast-forward from this ref too

                PUSH_COMMIT="$(git rev-parse --verify "$PUSH")"
                AHEAD_PUSH="$(git rev-list --count "${PUSH_COMMIT}..${LOCAL_COMMIT}")"
                BEHIND_PUSH="$BEHIND_UPSTREAM"

                if [ "$AHEAD_PUSH" -gt "0" ]; then

                    PRETTY_BRANCH="$(git_format_branch "$BRANCH" "$BEHIND_PUSH" "$AHEAD_PUSH")"

                    if [ "$BEHIND_PUSH" -gt "0" ]; then

                        WARNINGS+=("Can't push $(single_or_plural "$AHEAD_PUSH" commit commits) to branch $PRETTY_BRANCH in $REPO_LONG_NAME until upstream $(single_or_plural "$BEHIND_PUSH" "commit is" "commits are") resolved")

                    else

                        echo
                        console_message "${BOLD}${AHEAD_PUSH} $(single_or_plural "$AHEAD_PUSH" commit commits) to branch \"${BRANCH}\" in \"${REPO_NAME}\" $(single_or_plural "$AHEAD_PUSH" "hasn't" "haven't") been pushed:${RESET}" "" "$BOLD" "$YELLOW"
                        echo
                        echo "${NO_WRAP}$(git log "-$GIT_LOG_LIMIT" --oneline --decorate --color=always "${PUSH_COMMIT}..${LOCAL_COMMIT}")${WRAP}"

                        if [ "$AHEAD_PUSH" -gt "$GIT_LOG_LIMIT" ]; then

                            ((NOT_SHOWN = AHEAD_PUSH - GIT_LOG_LIMIT))

                            echo
                            echo "($NOT_SHOWN $(single_or_plural "$NOT_SHOWN" commit commits) not shown)"

                        fi

                        if [ "$DO_PUSH" -eq "1" ] && echo && get_confirmation "Attempt to push branch \"$BRANCH\" to remote \"$PUSH_REMOTE\"?" Y; then

                            git push "$PUSH_REMOTE" "$BRANCH:$BRANCH" && PUSHED_BRANCHES+=("$PRETTY_BRANCH") && AHEAD_PUSH=0 || WARNINGS+=("Can't push $(single_or_plural "$AHEAD_PUSH" commit commits) to branch $PRETTY_BRANCH in $REPO_LONG_NAME")

                        else

                            WARNINGS+=("Unpushed $(single_or_plural "$AHEAD_PUSH" commit commits) to branch $PRETTY_BRANCH in $REPO_LONG_NAME")

                        fi

                    fi

                fi

            else

                WARNINGS+=("Branch $PRETTY_BRANCH in $REPO_LONG_NAME doesn't have a \"push\" remote-tracking branch")

            fi

        done 4< <(

            # shellcheck disable=SC1090
            . "$SUBSHELL_SCRIPT_PATH" || exit

            git for-each-ref --format='
BRANCH="%(refname:short)"
LOCAL_COMMIT="%(objectname:short)"
IS_CURRENT_BRANCH="%(HEAD)"
%00' refs/heads/

        )

        if [ "${#UPDATED_BRANCHES[@]}" -gt "0" ]; then

            UPDATED_REPOS+=("${REPO_LONG_NAME}($(array_join_by ', ' "${UPDATED_BRANCHES[@]}"))")

        fi

        if [ "${#PUSHED_BRANCHES[@]}" -gt "0" ]; then

            PUSHED_REPOS+=("${REPO_LONG_NAME}($(array_join_by ', ' "${PUSHED_BRANCHES[@]}"))")

        fi

    else

        WARNINGS+=("No remotes in repository $REPO_LONG_NAME")

    fi

    CHANGES=()

    UNTRACKED="$(git ls-files --other --exclude-standard)" || die
    [ -z "$UNTRACKED" ] || CHANGES+=("untracked")

    git diff-files --quiet || CHANGES+=("unstaged")

    git diff-index --cached --quiet HEAD || CHANGES+=("uncommitted")

    if [ "${#CHANGES[@]}" -gt "0" ]; then

        WARNINGS+=("$(upper_first "$(array_join_oxford "${CHANGES[@]}")") changes in $REPO_LONG_NAME")

    fi

    if git rev-parse --verify -q refs/stash >/dev/null; then

        STASH_COUNT="$(git rev-list --walk-reflogs --count refs/stash)"

        WARNINGS+=("$STASH_COUNT $(single_or_plural "$STASH_COUNT" stash stashes) in repository $REPO_LONG_NAME")

    fi

    GIT_FILEMODE="$(git config core.fileMode 2>/dev/null)" || true
    GIT_IGNORECASE="$(git config core.ignoreCase 2>/dev/null)" || true
    GIT_PRECOMPOSEUNICODE="$(git config core.precomposeUnicode 2>/dev/null)" || true

    if is_windows; then

        [ "$GIT_FILEMODE" = "false" ] || { git config --bool core.fileMode "false" && echoc "Git option disabled: core.fileMode" "$BOLD" "$YELLOW"; } || die

    else

        [ -z "$GIT_FILEMODE" ] || [ "$GIT_FILEMODE" = "true" ] || { git config --bool core.fileMode "true" && echoc "Git option enabled: core.fileMode" "$BOLD" "$YELLOW"; } || die

    fi

    # TODO: check filesystem case-sensitivity rather than assuming macOS and Windows are case-insensitive
    if is_linux; then

        [ -z "$GIT_IGNORECASE" ] || [ "$GIT_IGNORECASE" = "false" ] || { git config --bool core.ignoreCase "false" && echoc "Git option disabled: core.ignoreCase" "$BOLD" "$YELLOW"; } || die

    else

        [ "$GIT_IGNORECASE" = "true" ] || { git config --bool core.ignoreCase "true" && echoc "Git option enabled: core.ignoreCase" "$BOLD" "$YELLOW"; } || die

    fi

    if is_macos; then

        [ "$GIT_PRECOMPOSEUNICODE" = "true" ] || { git config --bool core.precomposeUnicode "true" && echoc "Git option enabled: core.precomposeUnicode" "$BOLD" "$YELLOW"; } || die

    else

        [ -z "$GIT_PRECOMPOSEUNICODE" ] || [ "$GIT_PRECOMPOSEUNICODE" = "false" ] || { git config --bool core.precomposeUnicode "false" && echoc "Git option disabled: core.precomposeUnicode" "$BOLD" "$YELLOW"; } || die

    fi

    popd >/dev/null

    echo

done

echoc "All done. ${REPO_COUNT} $(single_or_plural "$REPO_COUNT" repository repositories) ${COMPLETION_VERB}." "$BOLD"
echo

if [ "${#UPDATED_REPOS[@]}" -gt "0" ]; then

    echoc "${#UPDATED_REPOS[@]} $(single_or_plural "${#UPDATED_REPOS[@]}" repository repositories) fast-forwarded from upstream:" "$BOLD" "$GREEN"
    printf '%s\n' "${UPDATED_REPOS[@]}" ""

fi

if [ "${#PUSHED_REPOS[@]}" -gt "0" ]; then

    echoc "${#PUSHED_REPOS[@]} $(single_or_plural "${#PUSHED_REPOS[@]}" repository repositories) pushed upstream:" "$BOLD" "$GREEN"
    printf '%s\n' "${PUSHED_REPOS[@]}" ""

fi

if [ "${#WARNINGS[@]}" -gt "0" ]; then

    echoc "${#WARNINGS[@]} $(single_or_plural "${#WARNINGS[@]}" "issue requires" "issues require") attention:" "$BOLD" "$RED"
    printf -- '- %s\n' "${WARNINGS[@]}"
    echo

fi
