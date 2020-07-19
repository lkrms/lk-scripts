#!/bin/bash
# shellcheck disable=SC1090,SC2015,SC2163

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"

IMAGE="ubuntu-18.04-minimal"
VM_PACKAGES=
VM_FILESYSTEM_MAPS=
VM_MEMORY="4096"
VM_CPUS="2"
VM_DISK_SIZE="80G"
VM_IPV4_ADDRESS=
VM_MAC_ADDRESS="$(printf '52:54:00:%02x:%02x:%02x' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))"
REFRESH_CLOUDIMG=0
STACKSCRIPT=
SKIP_PROMPTS=0
FORCE_DELETE=0

USAGE="
Usage:
  $(basename "$0") [options] vm_name

Boot a new QEMU/KVM instance from the current release of a cloud image.

Options:
  -i, --image <image_name>                              [$IMAGE]
  -r, --refresh-image
  -p, --packages <package,...>
  -f, --fs-maps <host_path,guest_path|...>
  -P, --preset <preset_name>
  -c, --cpus <count>                                    [$VM_CPUS]
  -m, --memory <size>               size is in MiB      [$VM_MEMORY]
  -s, --disk-size <size>            size is in GiB      [$VM_DISK_SIZE]
  -n, --network <network_name>      may be given as: 'bridge=ifname'
  -I, --ip-address <ipv4_address>   format must be: 'a.b.c.d/prefix'
  -M, --mac <52:54:00:xx:xx:xx>     uniqueness is not checked
  -S, --stackscript <script_path>   overrides --packages
  -u, --session                     qemu:///system -> qemu:///session
  -y, --yes                         skip prompts if possible
  -F, --force                       force off/delete if needed (implies -y)

  Supported images:
    ubuntu-20.04-minimal
    ubuntu-18.04-minimal
    ubuntu-16.04-minimal
    ubuntu-20.04
    ubuntu-18.04
    ubuntu-16.04
    ubuntu-14.04
    ubuntu-12.04

  Presets:
    linode16gb
    linode8gb
    linode4gb
    linode2gb
    linode1gb

  If --stackscript is specified:
    - you will be prompted to set StackScript fields found in the script
    - cloud-init will be configured to initialize a Linode-like environment
    - the specified script will be minified and added to runcmd in cloud-init
"

OPTS="$(getopt --options "i:rp:f:P:m:c:s:n:I:M:S:uyF" \
    --longoptions "image:,refresh-image,packages:,fs-maps:,preset:,memory:,cpus:,disk-size:,network:,ip-address:,mac:,stackscript:,session,yes,force" \
    --name "$(basename "$0")" \
    -- "$@")" || die "$USAGE"

eval "set -- $OPTS"

CLOUDIMG_POOL_ROOT="$(realpath "${CLOUDIMG_POOL_ROOT:-/var/lib/libvirt/images}")"
VM_POOL_ROOT="$CLOUDIMG_POOL_ROOT"
VM_NETWORK_DEFAULT="default"
LIBVIRT_URI="qemu:///system"
SUDO_OR_NOT=1

while :; do
    OPT="$1"
    shift
    case "$OPT" in
    -i | --image)
        IMAGE="$1"
        ;;
    -r | --refresh-image)
        REFRESH_CLOUDIMG=1
        continue
        ;;
    -p | --packages)
        VM_PACKAGES="$1"
        ;;
    -f | --fs-maps)
        VM_FILESYSTEM_MAPS="$1"
        ;;
    -P | --preset)
        case "$1" in
        linode1gb)
            VM_CPUS=1
            VM_MEMORY=1024
            VM_DISK_SIZE=25G
            ;;
        linode2gb)
            VM_CPUS=1
            VM_MEMORY=2048
            VM_DISK_SIZE=50G
            ;;
        linode4gb)
            VM_CPUS=2
            VM_MEMORY=4096
            VM_DISK_SIZE=80G
            ;;
        linode8gb)
            VM_CPUS=4
            VM_MEMORY=8192
            VM_DISK_SIZE=160G
            ;;
        linode16gb)
            VM_CPUS=6
            VM_MEMORY=16384
            VM_DISK_SIZE=320G
            ;;
        *)
            lk_warn "invalid preset '$1'"
            die "$USAGE"
            ;;
        esac
        ;;
    -m | --memory)
        VM_MEMORY="$1"
        ;;
    -c | --cpus)
        VM_CPUS="$1"
        ;;
    -s | --disk-size)
        VM_DISK_SIZE="$1"
        ;;
    -n | --network)
        VM_NETWORK="$1"
        ;;
    -I | --ip-address)
        VM_IPV4_ADDRESS="$1"
        ;;
    -M | --mac)
        VM_MAC_ADDRESS="$1"
        ;;
    -S | --stackscript)
        [ -f "$1" ] || {
            lk_warn "invalid StackScript '$1'"
            die "$USAGE"
        }
        STACKSCRIPT="$1"
        ;;
    -u | --session)
        VM_POOL_ROOT="$(realpath --canonicalize-missing \
            "${CLOUDIMG_SESSION_POOL_ROOT:-$HOME/.local/share/libvirt/images}")"
        VM_NETWORK_DEFAULT="bridge=virbr0"
        LIBVIRT_URI="qemu:///session"
        unset SUDO_OR_NOT
        continue
        ;;
    -F | --force)
        FORCE_DELETE=1
        ;&
    -y | --yes)
        SKIP_PROMPTS=1
        continue
        ;;
    --)
        break
        ;;
    esac
    shift
done
VM_NETWORK="${VM_NETWORK:-$VM_NETWORK_DEFAULT}"

VM_HOSTNAME="${1:-}"
[ -n "$VM_HOSTNAME" ] || die "$USAGE"

# OS_VARIANT: run `osinfo-query os` for options
case "$IMAGE" in

*20.04*minimal)
    IMAGE_NAME="ubuntu-20.04-minimal"
    IMAGE_URL="http://${UBUNTU_CLOUDIMG_HOST:-cloud-images.ubuntu.com}/minimal/releases/focal/release/ubuntu-20.04-minimal-cloudimg-amd64.img"
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/minimal/releases/focal/release/SHA256SUMS.gpg"
    )
    SHA_KEYRING="$LK_ROOT/share/keyrings/ubuntu-cloudimage-keyring.gpg"
    OS_VARIANT="ubuntu20.04"
    ;;

*20.04*)
    IMAGE_NAME="ubuntu-20.04"
    IMAGE_URL="http://${UBUNTU_CLOUDIMG_HOST:-cloud-images.ubuntu.com}/focal/current/focal-server-cloudimg-amd64.img"
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/focal/current/SHA256SUMS.gpg"
        "https://cloud-images.ubuntu.com/focal/current/SHA256SUMS"
    )
    SHA_KEYRING="$LK_ROOT/share/keyrings/ubuntu-cloudimage-keyring.gpg"
    OS_VARIANT="ubuntu20.04"
    ;;

*18.04*minimal)
    IMAGE_NAME="ubuntu-18.04-minimal"
    IMAGE_URL="http://${UBUNTU_CLOUDIMG_HOST:-cloud-images.ubuntu.com}/minimal/releases/bionic/release/ubuntu-18.04-minimal-cloudimg-amd64.img"
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/minimal/releases/bionic/release/SHA256SUMS.gpg"
    )
    SHA_KEYRING="$LK_ROOT/share/keyrings/ubuntu-cloudimage-keyring.gpg"
    OS_VARIANT="ubuntu18.04"
    ;;

*18.04*)
    IMAGE_NAME="ubuntu-18.04"
    IMAGE_URL="http://${UBUNTU_CLOUDIMG_HOST:-cloud-images.ubuntu.com}/bionic/current/bionic-server-cloudimg-amd64.img"
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/bionic/current/SHA256SUMS.gpg"
        "https://cloud-images.ubuntu.com/bionic/current/SHA256SUMS"
    )
    SHA_KEYRING="$LK_ROOT/share/keyrings/ubuntu-cloudimage-keyring.gpg"
    OS_VARIANT="ubuntu18.04"
    ;;

*16.04*minimal)
    IMAGE_NAME="ubuntu-16.04-minimal"
    IMAGE_URL="http://${UBUNTU_CLOUDIMG_HOST:-cloud-images.ubuntu.com}/minimal/releases/xenial/release/ubuntu-16.04-minimal-cloudimg-amd64-disk1.img"
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/minimal/releases/xenial/release/SHA256SUMS.gpg"
    )
    SHA_KEYRING="$LK_ROOT/share/keyrings/ubuntu-cloudimage-keyring.gpg"
    OS_VARIANT="ubuntu16.04"
    ;;

*16.04*)
    IMAGE_NAME="ubuntu-16.04"
    IMAGE_URL="http://${UBUNTU_CLOUDIMG_HOST:-cloud-images.ubuntu.com}/xenial/current/xenial-server-cloudimg-amd64-disk1.img"
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/xenial/current/SHA256SUMS.gpg"
        "https://cloud-images.ubuntu.com/xenial/current/SHA256SUMS"
    )
    SHA_KEYRING="$LK_ROOT/share/keyrings/ubuntu-cloudimage-keyring.gpg"
    OS_VARIANT="ubuntu16.04"
    ;;

*14.04*)
    IMAGE_NAME="ubuntu-14.04"
    IMAGE_URL="http://${UBUNTU_CLOUDIMG_HOST:-cloud-images.ubuntu.com}/trusty/current/trusty-server-cloudimg-amd64-disk1.img"
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/trusty/current/SHA256SUMS.gpg"
        "https://cloud-images.ubuntu.com/trusty/current/SHA256SUMS"
    )
    SHA_KEYRING="$LK_ROOT/share/keyrings/ubuntu-cloudimage-keyring.gpg"
    OS_VARIANT="ubuntu14.04"
    ;;

*12.04*)
    IMAGE_NAME="ubuntu-12.04"
    IMAGE_URL="http://${UBUNTU_CLOUDIMG_HOST:-cloud-images.ubuntu.com}/precise/current/precise-server-cloudimg-amd64-disk1.img"
    SHA_URLS=(
        "https://cloud-images.ubuntu.com/precise/current/SHA256SUMS.gpg"
        "https://cloud-images.ubuntu.com/precise/current/SHA256SUMS"
    )
    SHA_KEYRING="$LK_ROOT/share/keyrings/ubuntu-cloudimage-keyring.gpg"
    OS_VARIANT="ubuntu12.04"
    ;;

*)
    die "$IMAGE: cloud image unknown"
    ;;

esac

if [ -n "$STACKSCRIPT" ]; then
    lk_console_item "Processing StackScript" "$STACKSCRIPT"
    STACKSCRIPT_TAGS="$(grep -Eo '<(udf|UDF)(\s+[a-z]+="[^"]*")*\s*/>' "$STACKSCRIPT")"
    STACKSCRIPT_TAG_COUNT="$(wc -l <<<"$STACKSCRIPT_TAGS")"
    STACKSCRIPT_FIELDS=()
    while IFS=$'\n' read -rd $'\0' -u 4 NAME LABEL DEFAULT_EXISTS DEFAULT SELECT_TYPE SELECT_OPTIONS; do
        [ "${#STACKSCRIPT_FIELDS[@]}" -gt "0" ] ||
            lk_console_detail "$STACKSCRIPT_TAG_COUNT UDF $(lk_maybe_plural "$STACKSCRIPT_TAG_COUNT" "tag" "tags") found"
        NAME="${NAME%.}"
        LABEL="${LABEL%.}"
        DEFAULT_EXISTS="${DEFAULT_EXISTS%.}"
        DEFAULT="${DEFAULT%.}"
        SELECT_TYPE="${SELECT_TYPE%.}"
        SELECT_OPTIONS="${SELECT_OPTIONS%.}"
        ! lk_variable_declared "$NAME" ||
            declare -p "$NAME" | grep -Eq "^declare -x $NAME=" ||
            die "StackScript field $NAME conflicts with variable $NAME"
        echo
        if [ -n "$DEFAULT_EXISTS" ]; then
            lk_console_item "Optional:" "$NAME" "$BOLD$GREEN"
        else
            unset DEFAULT
            lk_console_item "Value required for" "$NAME" "$BOLD$RED"
        fi
        lk_console_detail "field $(("${#STACKSCRIPT_FIELDS[@]}" + 1)) of $STACKSCRIPT_TAG_COUNT"
        [ -z "$SELECT_TYPE" ] || lk_console_detail "$SELECT_TYPE:" "$SELECT_OPTIONS"
        [ -z "${DEFAULT:-}" ] || lk_console_detail "default:" "$DEFAULT"
        while :; do
            lk_is_false "$SKIP_PROMPTS" || {
                [ -z "${!NAME:-}" ] && [ -z "$DEFAULT_EXISTS" ] || {
                    lk_console_detail "using value:" "${!NAME-${DEFAULT:-}}" "$CYAN"
                    break
                }
            }
            eval "INITIAL_VALUE=\"\${$NAME-\${DEFAULT:-}}\""
            eval "$NAME=\"\$(lk_console_read \"\$LABEL:\" \"\" \${INITIAL_VALUE:+-i \"\$INITIAL_VALUE\"})\""
            [ -z "${!NAME}" ] && [ -z "$DEFAULT_EXISTS" ] || break
            lk_console_warning "$NAME is a required field"
        done
        [ "${!NAME:-}" != "${DEFAULT:-}" ] || eval "$NAME="
        STACKSCRIPT_FIELDS+=("$NAME")
        export "$NAME"
    done 4< <(cat <<<"$STACKSCRIPT_TAGS" |
        sed -E 's/<(udf|UDF)(\s+(name="([a-zA-Z_][a-zA-Z0-9_]*)"|label="([^"]*)"|(default)="([^"]*)"|(oneof|manyof)="([^"]*)"|[a-zA-Z]+="[^"]*"))*\s*\/>/\4\n\5\n\6\n\7\n\8\n\9/' |
        xargs -d $'\n' -n 6 printf '%s.\n%s.\n%s.\n%s.\n%s.\n%s.\0')
    STACKSCRIPT_ENV=
    [ "${#STACKSCRIPT_FIELDS[@]}" -eq "0" ] || {
        # printenv does no escaping, and cloud-init does no unescaping
        STACKSCRIPT_ENV="$(printenv | grep -E "^($(lk_implode '|' "${STACKSCRIPT_FIELDS[@]}"))=.+$" | sort || true)"
        echo
    }
fi

while VM_STATE="$(lk_maybe_sudo virsh domstate "$VM_HOSTNAME" 2>/dev/null)"; do
    [ "$VM_STATE" != "shut off" ] || unset VM_STATE
    lk_console_warning "Domain already exists: $VM_HOSTNAME"
    lk_is_true "$FORCE_DELETE" || lk_confirm "$BOLD${RED}OK to ${VM_STATE+force off, }delete and permanently remove all storage volumes for '$VM_HOSTNAME'?$RESET" N || die
    ${VM_STATE+lk_maybe_sudo virsh destroy "$VM_HOSTNAME"} || :
    lk_maybe_sudo virsh undefine --remove-all-storage "$VM_HOSTNAME" || :
done

lk_console_message "Ready to download and deploy"
echo "\
${BOLD}Name:$RESET               $BOLD$YELLOW$VM_HOSTNAME$RESET
${BOLD}Image:$RESET              $BOLD$CYAN$IMAGE_NAME$RESET
${BOLD}Memory:$RESET             $BOLD$YELLOW$VM_MEMORY$RESET
${BOLD}CPUs:$RESET               $BOLD$YELLOW$VM_CPUS$RESET
${BOLD}Disk size:$RESET          $VM_DISK_SIZE
${BOLD}Network:$RESET            $VM_NETWORK
${BOLD}IPv4 address:$RESET       ${VM_IPV4_ADDRESS:-<automatic>}
${BOLD}MAC address:$RESET        $VM_MAC_ADDRESS
${BOLD}Packages:$RESET           ${VM_PACKAGES:+${VM_PACKAGES//,/, }, }qemu-guest-agent
${BOLD}Filesystem maps:$RESET    ${VM_FILESYSTEM_MAPS:-<none>}
${BOLD}Libvirt service:$RESET    $BOLD$CYAN$LIBVIRT_URI$RESET
${BOLD}Disk image path:$RESET    $VM_POOL_ROOT
${BOLD}StackScript:$RESET        ${STACKSCRIPT:-<none>}${STACKSCRIPT_ENV+

StackScript environment:
  $([ -n "$STACKSCRIPT_ENV" ] && echo "${STACKSCRIPT_ENV//$'\n'/$'\n'  }" || echo "<empty>")}
"
lk_is_true "$SKIP_PROMPTS" || lk_confirm "OK to proceed?" Y

mkdir -p "$CACHE_DIR/cloud-images" &&
    cd "$CACHE_DIR/cloud-images" || die

FILENAME="${IMAGE_URL##*/}"
IMG_NAME="${FILENAME%.*}"

if [ ! -f "$FILENAME" ] || lk_is_true "$REFRESH_CLOUDIMG"; then

    lk_console_item "Downloading" "$FILENAME"

    wget --timestamping "$IMAGE_URL" || {
        rm -f "$FILENAME"
        die "error downloading $IMAGE_URL"
    }

    if [ "${#SHA_URLS[@]}" -eq "1" ]; then
        SHA_SUMS="$(curl "${SHA_URLS[0]}" | gpg --no-default-keyring --keyring "$SHA_KEYRING" --decrypt)" || die "error verifying ${SHA_URLS[0]}"
    else
        SHA_SUMS="$(curl "${SHA_URLS[1]}")" &&
            gpg --no-default-keyring --keyring "$SHA_KEYRING" --verify <(curl "${SHA_URLS[0]}") <(echo "$SHA_SUMS") || die "error verifying ${SHA_URLS[0]}"
    fi
    echo "$SHA_SUMS" >"SHASUMS-$IMAGE_NAME" || die "error writing to SHASUMS-$IMAGE_NAME"

fi

TIMESTAMP="$(gnu_stat --printf '%Y' "$FILENAME")"
CLOUDIMG_PATH="$CLOUDIMG_POOL_ROOT/cloud-images/$IMG_NAME-$TIMESTAMP.qcow2"
if sudo test -f "$CLOUDIMG_PATH"; then
    lk_console_message "$FILENAME is already available at $CLOUDIMG_PATH"
else
    grep -E "$(lk_escape_ere "$FILENAME")\$" "SHASUMS-$IMAGE_NAME" | shasum -a "${SHA_ALGORITHM:-256}" -c &&
        lk_console_item "Verified" "$FILENAME" "$BOLD$GREEN" ||
        die "$PWD$FILENAME: verification failed"
    sudo chmod -c 755 "$CLOUDIMG_POOL_ROOT" # some distros (e.g. Ubuntu) make this root-only by default
    sudo mkdir -p "$CLOUDIMG_POOL_ROOT/cloud-images"
    CLOUDIMG_FORMAT="$(qemu-img info --output=json "$FILENAME" | jq -r .format)"
    if [ "$CLOUDIMG_FORMAT" != "qcow2" ]; then
        lk_console_message "Converting $FILENAME (format: $CLOUDIMG_FORMAT) to $CLOUDIMG_PATH"
        sudo qemu-img convert -pO qcow2 "$FILENAME" "$CLOUDIMG_PATH"
    else
        lk_console_message "Copying $FILENAME (format: $CLOUDIMG_FORMAT) to $CLOUDIMG_PATH"
        sudo cp -v "$FILENAME" "$CLOUDIMG_PATH"
    fi
    sudo touch -r "$FILENAME" "$CLOUDIMG_PATH" &&
        sudo chmod -v 444 "$CLOUDIMG_PATH" &&
        lk_console_message "$FILENAME is now available at $CLOUDIMG_PATH"
fi

DISK_PATH="$VM_POOL_ROOT/$VM_HOSTNAME-$IMG_NAME-$TIMESTAMP.qcow2"
NOCLOUD_TEMP_PATH="$VM_HOSTNAME-$IMG_NAME-$TIMESTAMP-cloud-init.img"
NOCLOUD_PATH="$VM_POOL_ROOT/$NOCLOUD_TEMP_PATH"

if [ -e "$DISK_PATH" ]; then
    lk_console_item "Disk image already exists:" "$DISK_PATH"
    lk_is_true "$FORCE_DELETE" || lk_confirm "Destroy the existing image and start over?" N || exit
fi

NETWORK_CONFIG="\
version: 1
config:
  - type: physical
    name: eth0
    mac_address: $VM_MAC_ADDRESS
    subnets:"

if [ -n "$VM_IPV4_ADDRESS" ]; then
    SUBNET="${VM_IPV4_ADDRESS%%/*}"
    SUBNET="${SUBNET%.*}."
    NETWORK_CONFIG="\
$NETWORK_CONFIG
      - type: static
        address: $VM_IPV4_ADDRESS
        gateway: ${SUBNET}1
        dns_nameservers:
          - ${SUBNET}1"

else
    NETWORK_CONFIG="\
$NETWORK_CONFIG
      - type: dhcp"

fi

OPTIONS=()
FSTAB=()
MOUNT_DIRS=()
[ -z "$VM_FILESYSTEM_MAPS" ] || {
    IFS="|"
    # shellcheck disable=SC2206
    FILESYSTEMS=($VM_FILESYSTEM_MAPS)
    unset IFS

    for FILESYSTEM in "${FILESYSTEMS[@]}"; do
        IFS=","
        # shellcheck disable=SC2206
        FILESYSTEM_DIRS=($FILESYSTEM)
        unset IFS

        [ "${#FILESYSTEM_DIRS[@]}" -ge "2" ] || die "invalid filesystem map: $FILESYSTEM"
        SOURCE_DIR="${FILESYSTEM_DIRS[0]}"
        MOUNT_DIR="${FILESYSTEM_DIRS[1]}"
        MOUNT_NAME="qemufs${#MOUNT_DIRS[@]}"
        [ -d "$SOURCE_DIR" ] || die "$SOURCE_DIR: directory does not exist"

        FILESYSTEM_DIRS[1]="$MOUNT_NAME"
        IFS=","
        FILESYSTEM="${FILESYSTEM_DIRS[*]}"
        unset IFS

        OPTIONS+=(--filesystem "$FILESYSTEM")
        FSTAB+=("$MOUNT_NAME $MOUNT_DIR 9p defaults,nofail,trans=virtio,version=9p2000.L,posixacl,msize=262144,_netdev 0 0")
        MOUNT_DIRS+=("$MOUNT_DIR")
    done
}

[ -f "$HOME/.ssh/authorized_keys" ] || die "$HOME/.ssh/authorized_keys: file not found"
IFS=$'\n'
# shellcheck disable=SC2207
SSH_AUTHORIZED_KEYS=($(grep -Ev '^(#|\s*$)' "$HOME/.ssh/authorized_keys"))
unset IFS
[ "${#SSH_AUTHORIZED_KEYS[@]}" -gt "0" ] || die "$HOME/.ssh/authorized_keys: no keys"

PACKAGES=()
[ "$IMAGE_NAME" = "ubuntu-12.04" ] || PACKAGES+=("qemu-guest-agent")
[ -z "$VM_PACKAGES" ] || [ -n "$STACKSCRIPT" ] || {
    IFS=","
    # shellcheck disable=SC2206
    PACKAGES+=($VM_PACKAGES)
    unset IFS
}

RUN_CMD=()
WRITE_FILES=()
if [ -z "$STACKSCRIPT" ]; then
    USER_DATA="\
#cloud-config
ssh_pwauth: false
users:
  - uid: $UID
    name: $USER
    gecos: $(lk_full_name)
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
$(printf '      - %s\n' "${SSH_AUTHORIZED_KEYS[@]}")
package_upgrade: true
package_reboot_if_required: true
$(
        [ "$IMAGE_NAME" != "ubuntu-12.04" ] || printf '%s\n' \
            "apt_upgrade: true" \
            "ssh_authorized_keys:" "${SSH_AUTHORIZED_KEYS[@]/#/  - }"
    )"
else
    USER_DATA="\
#cloud-config
ssh_pwauth: true
disable_root: false
users: []
ssh_authorized_keys:
$(printf '  - %s\n' "${SSH_AUTHORIZED_KEYS[@]}")"

    STACKSCRIPT_LINES="$(
        if lk_command_exists shfmt; then
            shfmt -mn "$STACKSCRIPT"
        else
            lk_warn "unable to minify $STACKSCRIPT (shfmt not installed)"
            cat "$STACKSCRIPT"
        fi | sed 's/^/      /'
    )"
    RUN_CMD+=(
        "  - - env"
        "    - ${STACKSCRIPT_ENV//$'\n'/$'\n'    - }"
        "    - bash"
        "    - -c"
        "    - |"
        "      exec </dev/null"
        "$STACKSCRIPT_LINES"
    )
fi

USER_DATA="$USER_DATA
apt:
  primary:
    - arches: [default]
      uri: ${UBUNTU_APT_MIRROR:-http://archive.ubuntu.com/ubuntu}
$(
    [ "${#PACKAGES[@]}" -eq "0" ] ||
        printf '%s\n' "packages:" "${PACKAGES[@]/#/  - }"
    [ "${#FSTAB[@]}" -eq "0" ] || {
        FSTAB_CMD=("${FSTAB[@]/#/  - echo \"}")
        FSTAB_CMD=("${FSTAB_CMD[@]/%/\" >>/etc/fstab}")
        FSTAB_CMD+=("${MOUNT_DIRS[@]/#/  - mount }")
        RUN_CMD=(
            "  - mkdir -pv ${MOUNT_DIRS[*]}"
            "${FSTAB_CMD[@]}"
            ${RUN_CMD[@]+"${RUN_CMD[@]}"}
        )
    }
    # ubuntu-16.04-minimal leaves /etc/resolv.conf unconfigured if a static IP
    # is assigned (no resolvconf package?)
    [ -z "$VM_IPV4_ADDRESS" ] || [ "$IMAGE_NAME" != "ubuntu-16.04-minimal" ] ||
        WRITE_FILES+=(
            "  - content: |"
            "      nameserver ${SUBNET}1"
            "    path: /etc/resolv.conf"
        )
    # ubuntu-12.04 doesn't start a serial getty (or implement write_files)
    [ "$IMAGE_NAME" != "ubuntu-12.04" ] || {
        GETTY_SH='cat <<EOF >"/etc/init/ttyS0.conf"
start on stopped rc RUNLEVEL=[2345]
stop on runlevel [!2345]
respawn
exec /sbin/getty --keep-baud 115200,38400,9600 ttyS0 vt220
EOF
/sbin/initctl start ttyS0'
        RUN_CMD+=(
            "  - - bash"
            "    - -c"
            "    - |"
            "      ${GETTY_SH//$'\n'/$'\n'      }"
        )
    }
    # cloud-init on ubuntu-14.04 doesn't recognise the "apt" schema
    [[ ! "$IMAGE_NAME" =~ ^ubuntu-(14.04|12.04)$ ]] ||
        echo "\
apt_mirror: ${UBUNTU_APT_MIRROR:-http://archive.ubuntu.com/ubuntu}"
    [ "${#RUN_CMD[@]}" -eq "0" ] || {
        printf '%s\n' \
            "runcmd:" \
            "${RUN_CMD[@]}"
    }
    [ "${#WRITE_FILES[@]}" -eq "0" ] || {
        printf '%s\n' \
            "write_files:" \
            "${WRITE_FILES[@]}"
    }
)"

META_DATA="\
dsmode: local
instance-id: $(uuidgen)
local-hostname: $VM_HOSTNAME
$(
    # cloud-init on ubuntu-14.04 ignores the network-config file
    [ -z "$VM_IPV4_ADDRESS" ] ||
        [[ ! "$IMAGE_NAME" =~ ^ubuntu-(14.04|12.04)$ ]] ||
        echo "\
network-interfaces: |
  auto eth0
  iface eth0 inet static
  address $VM_IPV4_ADDRESS
  gateway ${SUBNET}1
  dns-nameservers ${SUBNET}1"
)"

NOCLOUD_META_DIR="$TEMP_DIR/NoCloud/$(lk_hostname)-$VM_HOSTNAME-$(lk_date_ymdhms)"
mkdir -p "$NOCLOUD_META_DIR"

echo "$NETWORK_CONFIG" >"$NOCLOUD_META_DIR/network-config.yml"
echo "$USER_DATA" >"$NOCLOUD_META_DIR/user-data.yml"
echo "$META_DATA" >"$NOCLOUD_META_DIR/meta-data.yml"

if lk_is_false "$SKIP_PROMPTS" && lk_confirm "Customise cloud-init data source?" N -t 60; then
    xdg-open "$NOCLOUD_META_DIR" || :
    lk_pause "Press any key to continue after making changes in $NOCLOUD_META_DIR . . . "
fi

cloud-localds -N "$NOCLOUD_META_DIR/network-config.yml" \
    "$NOCLOUD_TEMP_PATH" \
    "$NOCLOUD_META_DIR/user-data.yml" \
    "$NOCLOUD_META_DIR/meta-data.yml" &&
    maybe_sudo cp -fv "$NOCLOUD_TEMP_PATH" "$NOCLOUD_PATH" &&
    rm -f "$NOCLOUD_TEMP_PATH" || die

maybe_sudo qemu-img create \
    -f "qcow2" \
    -b "$CLOUDIMG_PATH" \
    -F "qcow2" \
    "$DISK_PATH" &&
    maybe_sudo qemu-img resize \
        -f "qcow2" \
        "$DISK_PATH" \
        "$VM_DISK_SIZE" || die

VM_NETWORK_TYPE="${VM_NETWORK%%=*}"
if [ "$VM_NETWORK_TYPE" = "$VM_NETWORK" ]; then
    VM_NETWORK_TYPE=network
else
    VM_NETWORK="${VM_NETWORK#*=}"
fi

maybe_sudo virt-install \
    --connect "$LIBVIRT_URI" \
    --name "$VM_HOSTNAME" \
    --memory "$VM_MEMORY" \
    --vcpus "$VM_CPUS" \
    --import \
    --os-variant "$OS_VARIANT" \
    --disk "$DISK_PATH",bus=virtio \
    --disk "$NOCLOUD_PATH",bus=virtio \
    --network "$VM_NETWORK_TYPE=$VM_NETWORK,mac=$VM_MAC_ADDRESS,model=virtio" \
    --graphics none \
    ${OPTIONS[@]+"${OPTIONS[@]}"} \
    --virt-type kvm
