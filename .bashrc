#!/bin/bash
# shellcheck disable=SC1090,SC1091,SC2015,SC2016,SC2030,SC2031,SC2068

LK_PROMPT_DISPLAYED=

eval "$(
    {
        SH_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" ||
            SH_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}" 2>/dev/null)" ||
            {
                [ ! -L "${BASH_SOURCE[0]}" ] &&
                    [ -f "$(dirname "${BASH_SOURCE[0]}")/bash/common-functions" ] &&
                    SH_PATH="${BASH_SOURCE[0]}"
            }
    } && LK_ROOT="$(cd "$(dirname "$SH_PATH")" && pwd -P)" &&
        echo "export LK_ROOT=\"$LK_ROOT\"" ||
        { [ "${BASH_SOURCE[0]}" = "$0" ] && echo "exit" || echo "return"; }
)"

. "$LK_ROOT/bash/common-functions"
lk_is_server || . "$LK_ROOT/bash/common-desktop"

function lk_find_largest() {
    gnu_find -L . -xdev -type f ${@+\( "$@" \)} -print0 | xargs -0 gnu_stat --format '%14s %N' | sort -nr | less
}

function lk_find_latest() {
    local i TYPE="${1:-}" TYPE_ARGS=()
    [[ "$TYPE" =~ ^[bcdflps]+$ ]] && shift || TYPE="f"
    for i in $(seq "${#TYPE}"); do
        TYPE_ARGS+=(${TYPE_ARGS[@]+-o} -type "${TYPE:$i-1:1}")
    done
    [ "${#TYPE_ARGS[@]}" -eq 2 ] || TYPE_ARGS=(\( "${TYPE_ARGS[@]}" \))
    gnu_find -L . -xdev -regextype posix-extended ${@+\( "$@" \)} "${TYPE_ARGS[@]}" -print0 | xargs -0 gnu_stat --format '%Y :%y %N' | sort -nr | cut -d: -f2- | less
}

function lk_ssl_client() {
    local HOST="${1:-}" PORT="${2:-}"
    [ -n "$HOST" ] || lk_warn "no hostname" || return
    [ -n "$PORT" ] || lk_warn "no port" || return
    openssl s_client -connect "$HOST":"$PORT" -servername "$HOST"
}

function lk_before_command() {
    [ "${LK_PROMPT_DISPLAYED:-0}" -eq "0" ] || [ "$BASH_COMMAND" = "$PROMPT_COMMAND" ] || {
        LK_LAST_COMMAND=($BASH_COMMAND)
        LK_LAST_COMMAND_START="$(lk_date "%s")"
    }
}

function lk_prompt() {
    local EXIT_STATUS="$?" PS=() SECS COMMAND IFS RED GREEN YELLOW BLUE BOLD RESET DIM STR LEN=25
    history -a
    [ "${LK_HISTORY_READ_NEW:-N}" = "N" ] || history -n
    eval "$(lk_get_colours "" | grep -E '^(RED|GREEN|YELLOW|BLUE|BOLD|RESET|DIM)=')"
    # if terminal doesn't support `dim`, try yellow
    [ -n "$DIM" ] || DIM="$YELLOW"
    if [ "${#LK_LAST_COMMAND[@]}" -gt "0" ]; then
        ((SECS = $(lk_date "%s") - LK_LAST_COMMAND_START)) || true
        if [ "$EXIT_STATUS" -ne "0" ] ||
            [ "$SECS" -gt "1" ] ||
            {
                [ "$(type -t "${LK_LAST_COMMAND[0]}")" != "builtin" ] &&
                    ! [[ "${LK_LAST_COMMAND[0]}" =~ ^(ls)$ ]]
            }; then
            COMMAND="${LK_LAST_COMMAND[*]}"
            COMMAND="${COMMAND//$'\r\n'/ }"
            COMMAND="${COMMAND//$'\n'/ }"
            COMMAND="${COMMAND//\\/\\\\}"
            PS+=("\n\[$DIM\]\d \t\[$RESET\] ")
            [ "$EXIT_STATUS" -eq "0" ] && {
                PS+=("\[$GREEN\]✔")
            } || {
                STR=" exit status $EXIT_STATUS"
                ((LEN += ${#STR}))
                PS+=("\[$RED\]✘$STR")
            }
            STR=" after ${SECS}s "
            PS+=("$STR\[$RESET$DIM\]")
            ((LEN = $(tput cols) - LEN - ${#STR}))
            [ "$LEN" -le "0" ] || PS+=("( ${COMMAND:0:$LEN} )")
            PS+=("\[$RESET\]\n")
        fi
        LK_LAST_COMMAND=()
    fi
    [ "$EUID" -ne "0" ] && PS+=("\[$BOLD$GREEN\]\u@") || PS+=("\[$BOLD$RED\]\u@")
    PS+=("\h\[$RESET\]:\[$BOLD$BLUE\]\w\[$RESET\]")
    IFS=
    PS1="${PS[*]}\\\$ "
    unset IFS
    LK_PROMPT_DISPLAYED=1
}

shopt -s checkwinsize
shopt -u promptvars

trap lk_before_command DEBUG
PROMPT_COMMAND="lk_prompt"
LK_LAST_COMMAND=()

# keep everything forever
shopt -s histappend
HISTCONTROL=
HISTIGNORE=
HISTSIZE=
HISTFILESIZE=
HISTTIMEFORMAT="%b %_d %Y %H:%M:%S %z "

[ ! -f "/etc/bash_completion" ] || . "/etc/bash_completion"

. /dev/stdin <<<"$(
    shopt -s nullglob
    [ ! -e "$LK_ROOT/config/settings" ] || . "$LK_ROOT/config/settings"
    LK_EXPORT="$(lk_load_env)"
    echo "$LK_EXPORT"
    eval "$LK_EXPORT"
    ! lk_command_exists shfmt || echo 'alias shellformat-test="shfmt -i 4 -l"'
    ! lk_command_exists youtube-dl || echo 'alias youtube-dl-audio="youtube-dl -x --audio-format m4a --audio-quality 0"'
    ! lk_is_macos || {
        echo 'alias duh="du -h -d 1 | sort -h"'
        echo 'alias flush-prefs="killall -u \"\$USER\" cfprefsd"'
        echo 'alias reset-audio="sudo launchctl unload /System/Library/LaunchDaemons/com.apple.audio.coreaudiod.plist && sudo launchctl load /System/Library/LaunchDaemons/com.apple.audio.coreaudiod.plist"'
        echo 'alias top="top -o cpu"'
        lk_command_exists node || [ ! -d "/usr/local/opt/node@8/bin" ] ||
            echo "export PATH=\"/usr/local/opt/node@8/bin:\$PATH\""
        PHP_PATHS=(/usr/local/opt/php*)
        for PHP_PATH in ${PHP_PATHS[@]+"${PHP_PATHS[@]}"}; do
            echo "export PATH=\"$PHP_PATH/sbin:$PHP_PATH/bin:\$PATH\""
            echo "export LDFLAGS=\"\${LDFLAGS:+\$LDFLAGS }-L$PHP_PATH/lib\""
            echo "export CPPFLAGS=\"\${CPPFLAGS:+\$CPPFLAGS }-I$PHP_PATH/include\""
        done
        [ -n "${JAVA_HOME:-}" ] || [ ! -x "/usr/libexec/java_home" ] ||
            ! /usr/libexec/java_home >/dev/null 2>&1 ||
            echo "export JAVA_HOME=\"\$(/usr/libexec/java_home)\""
    }
    ! lk_is_linux || {
        echo 'alias duh="du -h --max-depth 1 | sort -h"'
        ! lk_command_exists xdg-open || echo 'alias open=xdg-open'
    }
)"

function latest() {
    lk_find_latest "${1:-fl}" ! \( -type d -name .git -prune \)
}

function latest_dir() {
    latest d
}

function latest_all() {
    lk_find_latest "${1:-fl}"
}

function latest_all_dir() {
    lk_find_latest d
}

function find_all() {
    local FIND="${1:-}"
    [ -n "$FIND" ] || return
    shift
    gnu_find -L . -xdev -iname "*$FIND*" "$@"
}
