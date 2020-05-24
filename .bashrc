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

function lk_add_group_read() {
    local DIR="${1:-.}"
    [ -d "$DIR" ] || lk_warn "not a directory: $DIR" || return
    ! lk_is_root || lk_warn "can't run as root" || return
    sudo find "$DIR" -type f ! -perm -g=r -exec chmod -c g+r '{}' \;
    sudo find "$DIR" -type d ! -perm -g=rx -exec chmod -c g+rx '{}' \;
}

function lk_before_command() {
    [ "${LK_PROMPT_DISPLAYED:-0}" -eq "0" ] || [ "$BASH_COMMAND" = "$PROMPT_COMMAND" ] || {
        LK_LAST_COMMAND=($BASH_COMMAND)
        LK_LAST_COMMAND_START="$(lk_date "%s")"
    }
}

function lk_prompt() {
    local EXIT_STATUS="$?" PS=() SECS COMMAND IFS DIM STR LEN=25
    history -a
    [ "${LK_HISTORY_READ_NEW:-N}" = "N" ] || history -n
    # if terminal doesn't support `dim`, use yellow
    DIM="$(lk_coalesce "$LK_DIM" "$LK_YELLOW")"
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
            PS+=("\n\[$DIM\]\d \t\[$LK_RESET\] ")
            [ "$EXIT_STATUS" -eq "0" ] && {
                PS+=("\[$LK_GREEN\]✔")
            } || {
                STR=" exit status $EXIT_STATUS"
                ((LEN += ${#STR}))
                PS+=("\[$LK_RED\]✘$STR")
            }
            STR=" after ${SECS}s "
            PS+=("$STR\[$LK_RESET$DIM\]")
            ((LEN = $(tput cols) - LEN - ${#STR}))
            [ "$LEN" -le "0" ] || PS+=("( ${COMMAND:0:$LEN} )")
            PS+=("\[$LK_RESET\]\n")
        fi
        LK_LAST_COMMAND=()
    fi
    [ "$EUID" -ne "0" ] && PS+=("\[$LK_BOLD$LK_GREEN\]\u@") || PS+=("\[$LK_BOLD$LK_RED\]\u@")
    PS+=("\h\[$LK_RESET\]:\[$LK_BOLD$LK_BLUE\]\w\[$LK_RESET\]")
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
    [ ! -e "$LK_ROOT/etc/settings" ] || . "$LK_ROOT/etc/settings"
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

! lk_is_linux || {
    function lk_check_ext4() {
        local PAIRS SOURCE TARGET FSTYPE SIZE AVAIL
        findmnt -Pt ext4,ext3,ext2 -o SOURCE,TARGET,FSTYPE,SIZE,AVAIL | while IFS= read -r PAIRS; do
            eval "$PAIRS"
            lk_console_item "Mounted $FSTYPE filesystem found at:" "$SOURCE"
            sudo tune2fs -l "$SOURCE" | command grep -Ei '(filesystem state|mount count|last checked):'
            lk_echoc "($SIZE with $AVAIL available, mounted at $TARGET)" "$LK_YELLOW"
            echo
        done
    }

    function lk_check_sysctl() {
        lk_console_message "IPv4 and IPv6 parameters:"
        sysctl -ar 'net\..*\.(((default|all)\.rp_filter|tcp_syncookies|ip_forward|all\.forwarding)|accept_ra)$'
    }
}

! lk_is_arch || {
    function lk_makepkg() {
        makepkg --syncdeps --rmdeps --clean "$@" &&
            makepkg --printsrcinfo >.SRCINFO && {
            [ "$#" -gt "0" ] || lk_console_item "To install:" "${FUNCNAME[0]} --install"
        }
    }
}
