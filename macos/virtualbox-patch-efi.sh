#!/bin/bash

SCRIPT_PATH="${BASH_SOURCE[0]}"
[ -L "$SCRIPT_PATH" ] && SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

. "$SCRIPT_DIR/../bash/common" || exit 1
. "$SCRIPT_DIR/../bash/virtualbox-common" || exit 1

if [ "$#" -ne "1" ]; then

    echo "Usage: $(basename "$0") <uuid|vmname>"
    exit 1

fi

assert_is_macos

# this will exit if the VM doesn't exist
virtualbox_load_info "$1"

DST_DIR="$(dirname "$VM_CFGFILE")"
DST_SPARSE="$DST_DIR/$VM_NAME.efi.sparseimage"
FILE_EFI="/usr/standalone/i386/apfs.efi"

EFI_VDI="$DST_DIR/$VM_NAME.efi.vdi"
OLD_EFI_VDI="$EFI_VDI"
EFI_VDI_NUM=0

while [ -e "$EFI_VDI" ]; do

    (( EFI_VDI_NUM++ ))
    EFI_VDI="$DST_DIR/$VM_NAME.$EFI_VDI_NUM.efi.vdi"

done

# the following is adapted from: https://github.com/AlexanderWillner/runMacOSinVirtualBox/blob/master/runMacOSVirtualbox.sh
echo "Adding APFS drivers to EFI in '$EFI_VDI'..."

# just in case we didn't clean things up properly on a previous attempt
hdiutil detach /Volumes/EFI 2>/dev/null

if [ ! -f "$DST_SPARSE" ]; then

    hdiutil create -size 1m -fs MS-DOS -volname EFI "$DST_SPARSE" || exit 1

fi

EFI_DEVICE=$(hdiutil attach -nomount "$DST_SPARSE" 2>&1) || { echo "Couldn't mount EFI disk: $EFI_DEVICE"; exit 1; }

EFI_DEVICE=$(echo $EFI_DEVICE | egrep -o '/dev/disk[[:digit:]]{1}' | head -n1)

# add APFS driver to EFI
[ ! -e /Volumes/EFI ] || { echo "'/Volumes/EFI' already exists!"; exit 1; }
diskutil mount "${EFI_DEVICE}s1" || exit 1
mkdir -pv /Volumes/EFI/EFI/drivers || exit 1
cp -pvf "$FILE_EFI" /Volumes/EFI/EFI/drivers/ || exit 1

# create startup script to boot macOS or the macOS installer
cat <<EOT > /Volumes/EFI/startup.nsh
@echo -off
#set StartupDelay 0
load fs0:\EFI\drivers\apfs.efi
map -r
echo "Trying to find a bootable device..."
for %p in "macOS Install Data" "macOS Install Data\Locked Files\Boot Files" "OS X Install Data" "Mac OS X Install Data" "System\Library\CoreServices" ".IABootFiles"
  for %d in fs2 fs3 fs4 fs5 fs6 fs1
    if exist "%d:\%p\boot.efi" then
      echo "Booting: %d:\%p\boot.efi ..."
      stall 5000
      "%d:\%p\boot.efi"
    endif
  endfor
endfor
echo "Failed."
EOT

# close disk again
diskutil unmount "${EFI_DEVICE}s1" || exit 1
VBoxManage convertfromraw "$EFI_DEVICE" "$EFI_VDI" --format VDI || exit 1
diskutil eject "$EFI_DEVICE" || exit 1

echo -e "\nEFI VDI created at: $BLUE$EFI_VDI$RESET\n${BOLD}Add this to $BLUE$1$RESET$BOLD as the first hard drive.$RESET"

