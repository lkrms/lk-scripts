#!/bin/bash
# shellcheck disable=SC2015,SC2206,SC2207

set -euo pipefail

PING_HOSTNAME="one.one.one.one" # see https://blog.cloudflare.com/dns-resolver-1-1-1-1/
NTP_SERVER="ntp.lkrms.org"      #
MOUNT_OPTIONS="defaults"        # add ",noatime" if needed
TIMEZONE="Australia/Sydney"     # see /usr/share/zoneinfo
LOCALES=("en_AU" "en_GB")       # UTF-8 is enforced
LANGUAGE="en_AU:en_GB:en"
MIRROR="http://archlinux.mirror.lkrms.org/archlinux/\$repo/os/\$arch"

function die() {
    local EXIT_STATUS="$?"
    [ "$EXIT_STATUS" -ne "0" ] || EXIT_STATUS="1"
    [ "$#" -eq "0" ] || message "$1"
    exit "$EXIT_STATUS"
}

function message() {
    echo "$(basename "$0"): $1" >&2
}

function confirm() {
    local YN
    read -rp $'\n'"$1 [y/n] " YN
    [[ "$YN" =~ ^[yY]$ ]]
}

function get_secret() {
    local SECRET
    read -rsp $'\n'"$1 " SECRET
    echo "$SECRET"
}

function is_dryrun() {
    [ "${DRYRUN:-1}" -eq "1" ]
}

function maybe_dryrun() {
    if is_dryrun; then
        message "[DRY RUN] $*"
    else
        "$@"
    fi
}

function _lsblk() {
    lsblk --list --noheadings --output "$@"
}

function check_devices() {
    local COLUMN="${COLUMN:-TYPE}" MATCH="$1" LIST
    shift
    LIST="$(_lsblk "$COLUMN" --nodeps "$@")" &&
        echo "$LIST" | grep -Fx "$MATCH" >/dev/null &&
        ! echo "$LIST" | grep -Fxv "$MATCH" >/dev/null
}

function before_install() {
    message "checking network connection..."
    ping -c 1 "${PING_HOSTNAME:-one.one.one.one}" || die "no network"

    message "updating system clock..."
    configure_ntp "/etc/ntp.conf"
    maybe_dryrun timedatectl set-ntp true
}

function in_target() {
    maybe_dryrun arch-chroot /mnt "$@"
}

function configure_ntp() {
    local NTP_CONF
    [ -z "${NTP_SERVER:-}" ] || {
        NTP_CONF="server $NTP_SERVER iburst"
        [ -e "$1.orig" ] || maybe_dryrun cp -pv "$1" "$1.orig"
        maybe_dryrun sed -Ei -e 's/^(server|pool)\b/#&/' -e "0,/^#(server|pool)\b/{s/^#(server|pool)\b/\\n$NTP_CONF\\n\\n&/}" "$1"
    }
}

function configure_pacman() {
    [ -e "$1.orig" ] || maybe_dryrun cp -pv "$1" "$1.orig"
    maybe_dryrun sed -Ei 's/^#\s*(Color|TotalDownload)\s*$/\1/' "$1"
}

USAGE="
  $(basename "$0") root_partition boot_partition hostname username
  $(basename "$0") target_device hostname username

Current block devices:
$(lsblk)
"

[ -d "/sys/firmware/efi/efivars" ] || die "please reboot in UEFI mode"

# in case we're starting over
[ ! -d "/mnt/boot" ] || {
    maybe_dryrun umount /mnt/boot
    maybe_dryrun umount /mnt
} || die

case "$#" in
3)
    [ -e "$1" ] &&
        check_devices disk "$1" ||
        die "$USAGE"

    before_install

    confirm "Repartition $1? ALL DATA WILL BE LOST." || die

    message "Partitioning $1..."
    maybe_dryrun parted --script "$1" \
        mklabel gpt \
        mkpart fat32 2048s 260MiB \
        mkpart ext4 260MiB 100% \
        set 1 boot on &&
        maybe_dryrun partprobe "$1" &&
        PARTITIONS=($(_lsblk "TYPE,NAME" --paths "$1" | grep -Po '(?<=^part ).*')) &&
        [ "${#PARTITIONS[@]}" -eq "2" ] &&
        ROOT_PARTITION="${PARTITIONS[1]}" &&
        BOOT_PARTITION="${PARTITIONS[0]}" &&
        maybe_dryrun wipefs -a "$ROOT_PARTITION" &&
        maybe_dryrun wipefs -a "$BOOT_PARTITION" ||
        is_dryrun

    REPARTITIONED=1
    TARGET_HOSTNAME="$2"
    TARGET_USERNAME="$3"
    ;;

4)
    [ -e "$1" ] &&
        [ -e "$2" ] &&
        check_devices part "$1" "$2" ||
        die "$USAGE"

    before_install

    REPARTITIONED=0
    ROOT_PARTITION="$1"
    BOOT_PARTITION="$2"
    TARGET_HOSTNAME="$3"
    TARGET_USERNAME="$4"
    ;;

*)
    die "$USAGE"
    ;;

esac

TARGET_PASSWORD="${TARGET_PASSWORD:-}"
[ -n "$TARGET_PASSWORD" ] || {
    while :; do
        TARGET_PASSWORD="$(get_secret "Password for $TARGET_USERNAME:")" &&
            CONFIRM_PASSWORD="$(get_secret "Password for $TARGET_USERNAME (again):")"
        echo
        [ -n "$TARGET_PASSWORD" ] &&
            [ "$TARGET_PASSWORD" = "$CONFIRM_PASSWORD" ] &&
            break ||
            message "password missing or mismatched"
    done
}

message "probing partitions..."
maybe_dryrun partprobe

ROOT_PARTITION_TYPE="$(_lsblk FSTYPE "$ROOT_PARTITION")" || die "no block device at $ROOT_PARTITION"
BOOT_PARTITION_TYPE="$(_lsblk FSTYPE "$BOOT_PARTITION")" || die "no block device at $BOOT_PARTITION"

if [ -z "$BOOT_PARTITION_TYPE" ] || {
    [ "$BOOT_PARTITION_TYPE" = "vfat" ] &&
        ! confirm "$BOOT_PARTITION already has a vfat filesystem. Leave it as-is?"
}; then

    { [ "$REPARTITIONED" -eq "1" ] || confirm "OK to format $BOOT_PARTITION as FAT32?"; } && {
        message "formatting $BOOT_PARTITION..."
        maybe_dryrun mkfs.fat -n ESP -F 32 "$BOOT_PARTITION"
    } || die

elif [ "$BOOT_PARTITION_TYPE" != "vfat" ]; then

    die "unexpected filesystem at $BOOT_PARTITION: $BOOT_PARTITION_TYPE"

fi

[ -z "$ROOT_PARTITION_TYPE" ] || message "WARNING: unexpected filesystem at $ROOT_PARTITION: $ROOT_PARTITION_TYPE"

{ [ "$REPARTITIONED" -eq "1" ] || confirm "OK to format $ROOT_PARTITION as ext4?"; } && {
    message "formatting $ROOT_PARTITION..."
    maybe_dryrun mkfs.ext4 -L root "$ROOT_PARTITION"
} || die

message "mounting partitions..."
maybe_dryrun mount -o "${MOUNT_OPTIONS:-defaults}" "$ROOT_PARTITION" /mnt &&
    maybe_dryrun mkdir /mnt/boot &&
    maybe_dryrun mount -o "${MOUNT_OPTIONS:-defaults}" "$BOOT_PARTITION" /mnt/boot || die

message "configuring pacman..."
configure_pacman "/etc/pacman.conf"
[ -z "$MIRROR" ] ||
    is_dryrun ||
    echo "Server=$MIRROR" >/etc/pacman.d/mirrorlist # pacstrap copies this to the new system

message "installing system..."
maybe_dryrun pacstrap -i /mnt base linux linux-firmware efibootmgr grub mkinitcpio ntfs-3g ntp os-prober sudo

message "configuring system..."

LOCALES=(${LOCALES[@]+"${LOCALES[@]}"} "en_US")
for l in $(printf '%s\n' "${LOCALES[@]}" | sed 's/\..*$//' | sort | uniq); do
    maybe_dryrun sed -Ei "s/^#($l\\.UTF-8\\s+UTF-8)/\1/" "/mnt/etc/locale.gen"
done

is_dryrun || {
    genfstab -U /mnt >>/mnt/etc/fstab
    echo "%wheel ALL=(ALL) ALL" >"/mnt/etc/sudoers.d/90-wheel"
    {
        echo "LANG=${LOCALES[0]}.UTF-8"
        [ -z "${LANGUAGE:-}" ] || echo "LANGUAGE=$LANGUAGE"
    } >"/mnt/etc/locale.conf"
    echo "$TARGET_HOSTNAME" >"/mnt/etc/hostname"
    cat <<EOF >"/mnt/etc/hosts"
127.0.0.1 localhost
::1 localhost
127.0.1.1 $TARGET_HOSTNAME
EOF
}

maybe_dryrun ln -sfv "/usr/share/zoneinfo/${TIMEZONE:-UTC}" "/mnt/etc/localtime"
in_target hwclock --systohc

in_target locale-gen

in_target useradd -m "$TARGET_USERNAME" -G adm,wheel -s /bin/bash &&
    echo -e "$TARGET_PASSWORD\n$TARGET_PASSWORD" | in_target passwd "$TARGET_USERNAME" &&
    in_target passwd -l root

configure_pacman "/mnt/etc/pacman.conf"
configure_ntp "/mnt/etc/ntp.conf" &&
    in_target systemctl enable ntpd.service

! _lsblk "DISC-GRAN,DISC-MAX" --nodeps "$ROOT_PARTITION" "$BOOT_PARTITION" | grep -Ev '^\s*0B\s+0B\s*$' >/dev/null || {
    message "enabling fstrim..."
    in_target systemctl enable fstrim.timer # weekly
}

in_target grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB &&
    in_target grub-mkconfig -o /boot/grub/grub.cfg

message "Bootstrap complete. Reboot at your leisure."
