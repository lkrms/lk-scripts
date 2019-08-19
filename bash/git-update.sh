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

git_get_code_roots

[ "${#CODE_ROOTS[@]}" -gt "0" ] || die "Usage: $(basename "$0") [/code/root...]"

GIT_LOG_LIMIT="${GIT_LOG_LIMIT:-14}"

case "$(basename "$0")" in

*check*)
    DO_FETCH=0
    DO_PUSH=0
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

REPO_COUNT=0
UPDATED_REPOS=()
PUSHED_REPOS=()
WARNINGS=()

for CODE_ROOT in "${CODE_ROOTS[@]}"; do

    while IFS= read -u 3 -rd $'\0' REPO_ROOT; do

        REPO_ROOT="$(realpath "$REPO_ROOT")"

        git_is_dir_working_root "$REPO_ROOT" || continue

        ((++REPO_COUNT))

        pushd "$REPO_ROOT" >/dev/null || die

        REPO_NAME="${REPO_ROOT#$CODE_ROOT}"
        REPO_NAME="${REPO_NAME#/}"
        REPO_LONG_NAME="${CODE_ROOT}/${BOLD}${REPO_NAME}${RESET}"
        [ -n "$REPO_NAME" ] || {
            REPO_NAME="$REPO_ROOT"
            REPO_LONG_NAME="${BOLD}${REPO_NAME}${RESET}"
        }

        console_message "$MAIN_VERB repository:" "${REPO_LONG_NAME}" "$CYAN"

        IFS=$'\n'
        REPO_REMOTES=($(git remote))
        unset IFS

        if [ "${#REPO_REMOTES[@]}" -gt "0" ]; then

            if [ "$DO_FETCH" -eq "1" ]; then

                console_message "Fetching from ${#REPO_REMOTES[@]} $(single_or_plural "${#REPO_REMOTES[@]}" remote remotes):" "$(git_format_remotes "${REPO_REMOTES[@]}")" "$MAGENTA"

                git fetch --all --quiet

            fi

            UPDATED_BRANCHES=()
            PUSHED_BRANCHES=()

            while IFS= read -u 4 -rd $'\0' REF_CODE; do

                eval "$REF_CODE"

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
                            echo

                            if [ "$AHEAD_PUSH" -gt "$GIT_LOG_LIMIT" ]; then

                                ((NOT_SHOWN = AHEAD_PUSH - GIT_LOG_LIMIT))

                                echo "($NOT_SHOWN $(single_or_plural "$NOT_SHOWN" commit commits) not shown)"
                                echo

                            fi

                            if [ "$DO_PUSH" -eq "1" ] && get_confirmation "Attempt to push branch \"$BRANCH\" to remote \"$PUSH_REMOTE\"?" Y; then

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
UPSTREAM="%(upstream:short)"
UPSTREAM_REMOTE="%(upstream:remotename)"
PUSH="%(push:short)"
PUSH_REMOTE="%(push:remotename)"
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

        if ! git diff-files --quiet || ! git diff-index --cached --quiet HEAD; then

            WARNINGS+=("Uncommitted changes in $REPO_LONG_NAME")

        fi

        GIT_FILEMODE="$(git config --local core.fileMode 2>/dev/null)" || true

        if is_windows; then

            [ -z "$GIT_FILEMODE" ] || { git config --unset core.fileMode && echoc "Git option cleared: core.fileMode" "$BOLD" "$YELLOW"; } || die

        else

            [ "$GIT_FILEMODE" = "true" ] || { git config --bool core.fileMode "true" && echoc "Git option set: core.fileMode" "$BOLD" "$YELLOW"; } || die

        fi

        popd >/dev/null

        echo

    done 3< <(

        # shellcheck disable=SC1090
        . "$SUBSHELL_SCRIPT_PATH" || exit

        # within each CODE_ROOT, sort by depth then name
        for i in $(seq 0 "${DEFAULT_CODE_REPO_DEPTH:-2}"); do

            find "$CODE_ROOT" -mindepth "$i" -maxdepth "$i" -type d -print0 | sort -z

        done

    )

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
    printf '%s\n' "${WARNINGS[@]}" ""

fi
