#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
[ -L "$SCRIPT_PATH" ] && SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

. "$SCRIPT_DIR/../bash/common"
. "$SCRIPT_DIR/../bash/virtualbox-common"

[ "$#" -eq "1" ] || die "Usage: $(basename "$0") <uuid|vmname>"

assert_is_macos

# this will exit if the VM doesn't exist
virtualbox_load_info "$1"

# parts of the following are adapted from: https://github.com/AlexanderWillner/runMacOSinVirtualBox/blob/master/runMacOSVirtualbox.sh

DST_DIR="$(dirname "$VM_CFGFILE")"
DST_SPARSE="$DST_DIR/$VM_NAME.efi.sparseimage"
FILE_EFI="/usr/standalone/i386/apfs.efi"

EFI_VDI="$DST_DIR/$VM_NAME.efi.vdi"
OLD_EFI_VDI="$EFI_VDI"
EFI_VDI_NUM=0

while [ -e "$EFI_VDI" ]; do

  ((EFI_VDI_NUM++))
  EFI_VDI="$DST_DIR/$VM_NAME.$EFI_VDI_NUM.efi.vdi"

done

# just in case we didn't clean things up properly on a previous attempt
hdiutil detach /Volumes/EFI 2>/dev/null || true

if [ ! -f "$DST_SPARSE" ]; then

  hdiutil create -size 1m -fs MS-DOS -volname EFI "$DST_SPARSE"

fi

EFI_DEVICE=$(hdiutil attach -nomount "$DST_SPARSE")

EFI_DEVICE=$(
  set -euo pipefail
  echo $EFI_DEVICE | grep -Eo '/dev/disk[[:digit:]]{1}' | head -n1
)

# add APFS driver to EFI
[ ! -e /Volumes/EFI ] || die "Error: /Volumes/EFI already exists"
diskutil mount "${EFI_DEVICE}s1"
mkdir -pv /Volumes/EFI/EFI/drivers
cp -pvf "$FILE_EFI" /Volumes/EFI/EFI/drivers/

# create startup script to boot macOS or the macOS installer
cat <<EOT >/Volumes/EFI/startup.nsh
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
diskutil unmount "${EFI_DEVICE}s1"
VBoxManage convertfromraw "$EFI_DEVICE" "$EFI_VDI" --format VDI
diskutil eject "$EFI_DEVICE"

console_message "EFI VDI created at:" "$EFI_VDI" $GREEN
console_message "To continue, add as the first hard drive to VM:" "$VM_NAME" $BLUE
