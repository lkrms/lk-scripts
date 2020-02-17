#!/bin/bash
# shellcheck disable=SC1090,SC1091,SC2015,SC2016

LC_PROMPT_DISPLAYED=

# take advantage of printf support for strftime in Bash 4.2+
if [ "${BASH_VERSINFO[0]}" -eq "4" ] && [ "${BASH_VERSINFO[1]}" -ge "2" ] ||
    [ "${BASH_VERSINFO[0]}" -gt "4" ]; then
    function lc_date() {
        printf "%($1)T" -1
    }
else
    function lc_date() {
        date +"$1"
    }
fi

function lc_before_command() {
    [ "${LC_PROMPT_DISPLAYED:-0}" -eq "0" ] || [ "$BASH_COMMAND" = "$PROMPT_COMMAND" ] || {
        LC_LAST_COMMAND=($BASH_COMMAND)
        LC_LAST_COMMAND_START="$(lc_date "%s")"
    }
}

function lc_prompt() {
    local EXIT_CODE="$?" PS=() SECS COMMAND IFS RED GREEN BLUE BOLD RESET DIM STR LEN=25

    history -a
    [ "${LC_HISTORY_READ_NEW:-N}" = "N" ] || history -n

    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    BLUE="$(tput setaf 4)"
    BOLD="$(tput bold)"
    RESET="$(tput sgr0)"

    # if terminal doesn't support dim, use grey
    DIM="$(tput dim 2>/dev/null)" || DIM="$(tput setaf 8)"

    if [ "${#LC_LAST_COMMAND[@]}" -gt "0" ]; then

        ((SECS = $(lc_date "%s") - LC_LAST_COMMAND_START)) || true

        if [ "$EXIT_CODE" -ne "0" ] ||
            [ "$SECS" -gt "1" ] ||
            [ "$(type -t "${LC_LAST_COMMAND[0]}")" != "builtin" ] ||
            ! [[ "${LC_LAST_COMMAND[0]}" =~ ^(cd|echo|ls|popd|pushd)$ ]]; then

            COMMAND="${LC_LAST_COMMAND[*]}"
            COMMAND="${COMMAND//$'\r\n'/ }"
            COMMAND="${COMMAND//$'\n'/ }"
            COMMAND="${COMMAND//\\/\\\\}"

            PS+=("\n\[$DIM\]\d \t\[$RESET\] ")

            [ "$EXIT_CODE" -eq "0" ] && {
                PS+=("\[$GREEN\]✔")
            } || {
                STR=" exit status $EXIT_CODE"
                ((LEN += ${#STR}))
                PS+=("\[$RED\]✘$STR")
            }

            STR=" after ${SECS}s "
            PS+=("$STR\[$RESET$DIM\]")
            ((LEN = $(tput cols) - LEN - ${#STR}))
            [ "$LEN" -le "0" ] || PS+=("( ${COMMAND:0:$LEN} )")
            PS+=("\[$RESET\]\n")

        fi

        LC_LAST_COMMAND=()

    fi

    [ "$EUID" -ne "0" ] && PS+=("\[$BOLD$GREEN\]\u@") || PS+=("\[$BOLD$RED\]\u@")
    PS+=("\h\[$RESET\]:\[$BOLD$BLUE\]\w\[$RESET\]")

    IFS=
    PS1="${PS[*]}\\\$ "
    unset IFS

    LC_PROMPT_DISPLAYED=1

}

shopt -u promptvars

trap lc_before_command DEBUG
PROMPT_COMMAND="lc_prompt"
LC_LAST_COMMAND=()

# keep everything forever
shopt -s histappend
HISTCONTROL=
HISTIGNORE=
HISTSIZE=
HISTFILESIZE=
HISTTIMEFORMAT="%b %_d %Y %H:%M:%S %z "

. /dev/stdin <<<"$(
    set -euo pipefail
    SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
    SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

    . "$SCRIPT_DIR/bash/common"

    variable_exists "ADD_TO_PATH" || ADD_TO_PATH=()

    ADD_TO_PATH+=("$ROOT_DIR/bin")

    # TODO: move executable scripts into bin and remove this
    ADD_TO_PATH+=("$ROOT_DIR" "$ROOT_DIR/bash")

    # TODO: remove ROOT_DIR/macos, ROOT_DIR/linux
    ! is_macos || ADD_TO_PATH+=("$ROOT_DIR/bin/macos" "$ROOT_DIR/macos")
    ! is_linux || ADD_TO_PATH+=("$ROOT_DIR/bin/linux" "$ROOT_DIR/linux")
    ! is_ubuntu || ADD_TO_PATH+=("$ROOT_DIR/bin/ubuntu")

    ADD_TO_PATH+=("$HOME/.local/bin")

    for i in "${!ADD_TO_PATH[@]}"; do

        ! [[ ":$PATH:" == *":${ADD_TO_PATH[$i]}:"* ]] &&
            [ -d "${ADD_TO_PATH[$i]}" ] ||
            unset "ADD_TO_PATH[$i]"

    done

    # shellcheck disable=SC2016
    if [ "${#ADD_TO_PATH[@]}" -gt "0" ]; then

        EXPORT_PATH="export PATH=\"\$PATH:$(array_join_by ":" "${ADD_TO_PATH[@]}")\""
        echo "$EXPORT_PATH"
        eval "$EXPORT_PATH"

    fi

    echo ". \"$ROOT_DIR/bash/common-functions\""

    echo "export LINAC_ROOT_DIR=\"$ROOT_DIR\""

    if ! is_root && [ -n "${SCREENSHOT_DIR:-}" ]; then

        [ -d "$SCREENSHOT_DIR" ] || mkdir -p "$SCREENSHOT_DIR" || true
        [ ! -d "$SCREENSHOT_DIR" ] || echo "export LINAC_SCREENSHOT_DIR=\"$SCREENSHOT_DIR\""

    fi

    if is_macos; then

        echo 'alias duh="du -h -d 1 | sort -h"'
        echo 'alias flush-prefs="killall -u \"\$USER\" cfprefsd"'
        echo 'alias reset-audio="sudo launchctl unload /System/Library/LaunchDaemons/com.apple.audio.coreaudiod.plist && sudo launchctl load /System/Library/LaunchDaemons/com.apple.audio.coreaudiod.plist"'
        echo 'alias top="top -o cpu"'

        command_exists node || [ ! -d "/usr/local/opt/node@8/bin" ] ||
            echo "export PATH=\"/usr/local/opt/node@8/bin:\$PATH\""

        shopt -s nullglob
        PHP_PATHS=(/usr/local/opt/php*)
        shopt -u nullglob

        [ "${#PHP_PATHS[@]}" -lt "2" ] ||
            echo "WARNING: multiple PHP installations detected and added to PATH:$(printf -- '\n- %s' "${PHP_PATHS[@]}")" >&2

        for PHP_PATH in "${!PHP_PATHS[@]}"; do

            echo "export PATH=\"${PHP_PATHS[$PHP_PATH]}/sbin:${PHP_PATHS[$PHP_PATH]}/bin:\$PATH\""
            echo "export LDFLAGS=\"\${LDFLAGS:+\$LDFLAGS }-L${PHP_PATHS[$PHP_PATH]}/lib\""
            echo "export CPPFLAGS=\"\${CPPFLAGS:+\$CPPFLAGS }-I${PHP_PATHS[$PHP_PATH]}/include\""

        done

        if [ -z "${JAVA_HOME:-}" ] && [ -x "/usr/libexec/java_home" ] && /usr/libexec/java_home >/dev/null 2>&1; then

            JAVA_HOME="$(/usr/libexec/java_home)" &&
                echo "export JAVA_HOME=\"$JAVA_HOME\""

        fi

    else

        is_root || load_linuxbrew Y Y || true

        echo 'alias duh="du -h --max-depth 1 | sort -h"'

        ! command_exists xdg-open || echo 'alias open=xdg-open'

        ! command_exists virsh || is_root || [ -z "$HOME" ] || {
            mkdir -p "$HOME/.local/var/log" &&
                echo 'alias debug-libvirt="export LIBVIRT_DEBUG=1;export LIBVIRT_LOG_OUTPUTS=\"1:file:\$HOME/.local/var/log/virsh.log\""' || true
        }

    fi

    ! command_exists shfmt || echo 'alias shellformat-test="shfmt -i 4 -l ."'
    ! command_exists youtube-dl || echo 'alias youtube-dl-audio="youtube-dl -x --audio-format mp3 --audio-quality 0"'

)"

function is_macos() {

    [ "$(uname -s)" = "Darwin" ]

}

function _latest() {

    local TYPE="${1:-}" COMMAND i

    [[ "$TYPE" =~ ^[bcdflps]+$ ]] && shift || TYPE="f"

    if is_macos; then

        COMMAND=(find -xE . \()

    else

        COMMAND=(find . -xdev -regextype posix-extended \()

    fi

    [ "$#" -eq "0" ] || COMMAND+=("$@")

    COMMAND+=(\()

    if [ "${#TYPE}" -eq "1" ]; then

        COMMAND+=(-type "$TYPE")

    else

        COMMAND+=(\()

        for i in $(seq "${#TYPE}"); do

            COMMAND+=(-type "${TYPE:$i-1:1}" -o)

        done

        COMMAND[${#COMMAND[@]} - 1]=\)

    fi

    COMMAND+=(-print0 \) \))

    if is_macos; then

        "${COMMAND[@]}" | xargs -0 stat -f '%m :%Sm %N%SY' | sort -nr | cut -d: -f2- | less

    else

        # use sed to remove quotes around file names
        "${COMMAND[@]}" | xargs -0 stat --format '%Y :%y %N' | sed -Ee "s/( -> )(['\"])(([^\2]|\\\\\2|\2\\\\\2\2)*)\2\$/\1\3/" -e "s/^([^'\"]+)(['\"])(([^\2]|\\\\\2|\2\\\\\2\2)*)\2( -> |\$)/\1\3\5/" -e "s/'\\''//" | sort -nr | cut -d: -f2- | less

    fi

}

# files after excluding .git directories (and various others we don't care about)
function latest() {
    _latest "${1:-fl}" \! \( \( -type d \( -name .git -o -path "*/.*/google-chrome" -o -path "*/.*/Cache" -o -path "*/.*/GPUCache" -o -path "*/.*/Local Storage" \) -prune \) -o \( -type f -regex '.*/(Cookies|QuotaManager)(-journal)?$' \) \)
}

# directories after excluding .git directories
function latest-dir() {
    latest d
}

# all files
function latest-all() {
    _latest "${1:-fl}"
}

# all directories
function latest-all-dir() {
    _latest d
}

function find-all() {

    local FIND="${1:-}"

    [ -n "$FIND" ] || {
        echo "usage: ${FUNCNAME[0]} search-term [find-arg ...]" >&2
        return 1
    }

    shift

    if is_macos; then

        find -x . -iname "*$FIND*" "$@"

    else

        find . -xdev -iname "*$FIND*" "$@"

    fi

}

function with-repos() {

    local REPO_COMMAND='echo "$1"'

    [ "$#" -eq "0" ] || REPO_COMMAND="$*"

    find . -type d -exec test -d "{}/.git" \; -print0 -prune | sort -z | xargs -0 -n 1 bash -c 'cd "$1" && { printf "\nRunning in: %s\n\n" "$1"; '"$REPO_COMMAND"'; }' bash

}

if command -v nextcloudcmd >/dev/null 2>&1; then

    function _cloud_sync() {

        local SOURCE_DIR="$1" SERVER_URL="$2"

        [ -d "$SOURCE_DIR" ] || {
            echo "Source directory not found: $SOURCE_DIR" >&2
            return 1
        }

        [ -n "$SERVER_URL" ] || {
            echo "Server URL required" >&2
            return 1
        }

        shift 2

        if [ -f "$HOME/.config/Nextcloud/sync-exclude.lst" ]; then

            nextcloudcmd "$@" --exclude "$HOME/.config/Nextcloud/sync-exclude.lst" "$SOURCE_DIR" "$SERVER_URL"

        else

            nextcloudcmd "$@" "$SOURCE_DIR" "$SERVER_URL"

        fi

    }

fi

function _cloud_check() {

    local SOURCE_DIR="$1" CONFLICTS=0

    [ -d "$SOURCE_DIR" ] || {
        echo "Source directory not found: $SOURCE_DIR" >&2
        return 1
    }

    echo -e "Looking for conflicts in: $SOURCE_DIR\n" >&2

    while IFS= read -d $'\0' -r LINE; do

        echo "$LINE"
        ((++CONFLICTS))

    done < <(find "$SOURCE_DIR" -iname "*conflicted copy*" -print0)

    [ "$CONFLICTS" -gt "0" ] || echo "No conflicts found" >&2
    echo >&2

}

# shellcheck disable=SC2142
alias files-count="find . -mindepth 1 -maxdepth 1 -type d -exec bash -c 'printf \"%s: %s\\n\" \"\$(find \"\$1\" -type f | wc -l)\" \"\$1\"' bash '{}' \; | sort -n"
alias rln="gnu_ln -r"
