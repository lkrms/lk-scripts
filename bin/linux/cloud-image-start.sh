#!/bin/bash
# shellcheck disable=SC1090,SC2015

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"

[ "$#" -gt "0" ] || die "
  $(basename "$0") vm_hostname [memory cpus disk_size network ipv4_address/prefix mac_address image]"

# TODO: validate the following (including MAC uniqueness)
VM_HOSTNAME="$1"
VM_MEMORY="${2:-1024}"
VM_CPUS="${3:-2}"
VM_DISK_SIZE="${4:-10G}"
VM_NETWORK="${5:-default}"
VM_IPV4_ADDRESS="${6:-}"
VM_MAC_ADDRESS="${7:-$(printf '52:54:00:%02x:%02x:%02x' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))}"
IMAGE="${8:-ubuntu-18.04-minimal}"

# OS_VARIANT: run `osinfo-query os` for options
case "$IMAGE" in

*18.04*)
    IMAGE_NAME="ubuntu18.04"
    IMAGE_URL="http://${UBUNTU_CLOUDIMG_HOST:-cloud-images.ubuntu.com}/minimal/releases/bionic/release/ubuntu-18.04-minimal-cloudimg-amd64.img"
    SHA_URL="http://${UBUNTU_CLOUDIMG_HOST:-cloud-images.ubuntu.com}/minimal/releases/bionic/release/SHA256SUMS.gpg"
    SHA_KEYRING="/usr/share/keyrings/ubuntu-cloudimage-keyring.gpg"
    OS_VARIANT="ubuntu18.04"
    ;;

*16.04*)
    IMAGE_NAME="ubuntu16.04"
    IMAGE_URL="http://${UBUNTU_CLOUDIMG_HOST:-cloud-images.ubuntu.com}/minimal/releases/xenial/release/ubuntu-16.04-minimal-cloudimg-amd64-disk1.img"
    SHA_URL="http://${UBUNTU_CLOUDIMG_HOST:-cloud-images.ubuntu.com}/minimal/releases/xenial/release/SHA256SUMS.gpg"
    SHA_KEYRING="/usr/share/keyrings/ubuntu-cloudimage-keyring.gpg"
    OS_VARIANT="ubuntu16.04"
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

    SHA_SUMS="$(curl "$SHA_URL" | gpg --no-default-keyring --keyring "$SHA_KEYRING" --decrypt)" || die "error verifying $SHA_URL"
    echo "$SHA_SUMS" >"SHASUMS-$IMAGE_NAME" || die "error writing to SHASUMS-$IMAGE_NAME"

fi

CLOUDIMG_POOL_ROOT="$(realpath "${CLOUDIMG_POOL_ROOT:-/var/lib/libvirt/images}")"
TIMESTAMP="$(gnu_stat --printf '%Y' "$FILENAME")"
CLOUDIMG_PATH="$CLOUDIMG_POOL_ROOT/cloud-images/$IMG_NAME-$TIMESTAMP.qcow2"
if sudo test -f "$CLOUDIMG_PATH"; then
    lk_console_message "$FILENAME is already available at $CLOUDIMG_PATH"
else
    grep -E "$(lk_escape_ere "$FILENAME")\$" "SHASUMS-$IMAGE_NAME" | shasum -a "${SHA_ALGORITHM:-256}" -c &&
        lk_console_item "Verified" "$FILENAME" "$BOLD$GREEN" ||
        die "$PWD$FILENAME: verification failed"
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

DISK_PATH="$CLOUDIMG_POOL_ROOT/$VM_HOSTNAME-$IMG_NAME-$TIMESTAMP.qcow2"
NOCLOUD_TEMP_PATH="$VM_HOSTNAME-$IMG_NAME-$TIMESTAMP-cloud-init.img"
NOCLOUD_PATH="$CLOUDIMG_POOL_ROOT/$NOCLOUD_TEMP_PATH"

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

cloud-localds -N <(echo "$NETWORK_CONFIG") "$NOCLOUD_TEMP_PATH" "$CONFIG_DIR/cloud-init/user-data" <(echo -e "dsmode: local\ninstance-id: $(uuidgen)\nlocal-hostname: $VM_HOSTNAME") &&
    sudo cp -fv "$NOCLOUD_TEMP_PATH" "$NOCLOUD_PATH" &&
    rm -f "$NOCLOUD_TEMP_PATH" || die

sudo qemu-img create \
    -f "qcow2" \
    -b "./cloud-images/$IMG_NAME-$TIMESTAMP.qcow2" \
    -F "qcow2" \
    "$DISK_PATH" &&
    sudo qemu-img resize \
        -f "qcow2" \
        "$DISK_PATH" \
        "$VM_DISK_SIZE" || die

sudo virt-install \
    --name "$VM_HOSTNAME" \
    --memory "$VM_MEMORY" \
    --vcpus "$VM_CPUS" \
    --import \
    --os-variant "$OS_VARIANT" \
    --disk "$DISK_PATH",bus=virtio \
    --disk "$NOCLOUD_PATH",bus=virtio \
    --network network="$VM_NETWORK",mac="$VM_MAC_ADDRESS",model=virtio \
    --graphics none \
    --virt-type kvm
