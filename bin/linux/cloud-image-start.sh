#!/bin/bash
# shellcheck disable=SC1090,SC2015

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"

CLOUDIMG_POOL_ROOT="$(realpath "${CLOUDIMG_POOL_ROOT:-/var/lib/libvirt/images}")"
case "$(basename "$0")" in
*session*)
    VM_POOL_ROOT="$(realpath "${CLOUDIMG_SESSION_POOL_ROOT:-$HOME/.local/share/libvirt/images}")"
    VM_NETWORK="bridge=virbr0"
    LIBVIRT_URI="qemu:///session"
    ;;
*)
    VM_POOL_ROOT="$CLOUDIMG_POOL_ROOT"
    VM_NETWORK="default"
    LIBVIRT_URI="qemu:///system"
    SUDO_OR_NOT=1
    ;;
esac

[ "$#" -gt "0" ] || die "
  $(basename "$0") vm_hostname [memory cpus disk_size network ipv4_address filesystem_maps packages mac_address image]

Defaults:
  MEMORY=2048
  CPUS=1
  DISK_SIZE=20G
  NETWORK=$VM_NETWORK
    Connect to bridge device BRIDGE using \"bridge=BRIDGE\"
  IPV4_ADDRESS=
    Added to cloud-init network-config file
    Must include a prefix, e.g. \"192.168.122.10/24\"
  FILESYSTEM_MAPS=
    e.g. \"/host/path,/guest/path|/host/path2,/guest/path2\"
  PACKAGES=
    e.g. \"apache2,mariadb-server,php-fpm\"
    Always installed: qemu-guest-agent
  MAC_ADDRESS=52:54:00:xx:xx:xx
    Randomly generated without checking uniqueness
  IMAGE=ubuntu-18.04-minimal

Images available:
  ubuntu-18.04-minimal
  ubuntu-18.04
  ubuntu-16.04-minimal
  ubuntu-16.04
  ubuntu-14.04"

# TODO: validate the following (including MAC uniqueness)
VM_HOSTNAME="$1"
VM_MEMORY="${2:-2048}"
VM_CPUS="${3:-1}"
VM_DISK_SIZE="${4:-20G}"
VM_NETWORK="${5:-$VM_NETWORK}"
VM_IPV4_ADDRESS="${6:-}"
VM_FILESYSTEM_MAPS="${7:-}"
VM_PACKAGES="${8:-}"
VM_MAC_ADDRESS="${9:-$(printf '52:54:00:%02x:%02x:%02x' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))}"
IMAGE="${10:-ubuntu-18.04-minimal}"

# OS_VARIANT: run `osinfo-query os` for options
case "$IMAGE" in

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
        "http://cloud-images.ubuntu.com/bionic/current/SHA256SUMS"
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
        "http://cloud-images.ubuntu.com/xenial/current/SHA256SUMS.gpg"
        "http://cloud-images.ubuntu.com/xenial/current/SHA256SUMS"
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

*)
    die "$IMAGE: cloud image unknown"
    ;;

esac

mkdir -p "$CACHE_DIR/cloud-images" &&
    cd "$CACHE_DIR/cloud-images" || die

FILENAME="${IMAGE_URL##*/}"
IMG_NAME="${FILENAME%.*}"

if [ ! -f "$FILENAME" ] || lk_is_true "${LK_CLOUDIMG_REFRESH:-1}"; then

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

[ ! -e "$DISK_PATH" ] || die "disk already exists: $DISK_PATH"

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
        MOUNT_NAME="${MOUNT_DIR//\//_}"
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
apt:
  primary:
    - arches: [default]
      uri: ${UBUNTU_APT_MIRROR:-http://archive.ubuntu.com/ubuntu}
package_upgrade: true
package_reboot_if_required: true
packages:
  - qemu-guest-agent
$(
    [ -z "$VM_PACKAGES" ] || {
        IFS=","
        # shellcheck disable=SC2206
        PACKAGES=($VM_PACKAGES)
        unset IFS
        printf '%s\n' "${PACKAGES[@]/#/  - }"
    }
    [ "${#FSTAB[@]}" -eq "0" ] || {
        FSTAB_CMD=("${FSTAB[@]/#/  - echo \"}")
        FSTAB_CMD=("${FSTAB_CMD[@]/%/\" >>/etc/fstab}")
        FSTAB_CMD+=("${MOUNT_DIRS[@]/#/  - mount }")
        printf '%s\n' \
            "runcmd:" \
            "  - mkdir -pv ${MOUNT_DIRS[*]}" \
            "${FSTAB_CMD[@]}"
    }
    # ubuntu-16.04-minimal leaves /etc/resolv.conf unconfigured if a static IP is assigned (no resolvconf package?)
    [ -z "$VM_IPV4_ADDRESS" ] || [ "$IMAGE_NAME" != "ubuntu-16.04-minimal" ] || echo "\
write_files:
  - content: |
      nameserver ${SUBNET}1
    path: /etc/resolv.conf"
    # cloud-init on ubuntu-14.04 doesn't recognise the "apt" schema
    [ "$IMAGE_NAME" != "ubuntu-14.04" ] || echo "\
apt_mirror: ${UBUNTU_APT_MIRROR:-http://archive.ubuntu.com/ubuntu}"
)"

META_DATA="\
dsmode: local
instance-id: $(uuidgen)
local-hostname: $VM_HOSTNAME
$(
    # cloud-init on ubuntu-14.04 ignores the network-config file
    [ -z "$VM_IPV4_ADDRESS" ] || [ "$IMAGE_NAME" != "ubuntu-14.04" ] || echo "\
network-interfaces: |
  iface eth0 inet static
  address $VM_IPV4_ADDRESS
  gateway ${SUBNET}1
  dns-nameserver ${SUBNET}1"
)"

echo "$NETWORK_CONFIG" >network-config.latest.yml
echo "$USER_DATA" >user-data.latest.yml
echo "$META_DATA" >meta-data.latest.yml

cloud-localds -N <(echo "$NETWORK_CONFIG") "$NOCLOUD_TEMP_PATH" <(echo "$USER_DATA") <(echo "$META_DATA") &&
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
