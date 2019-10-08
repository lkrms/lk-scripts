#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

# shellcheck source=../bash/common-dev
. "$SCRIPT_DIR/../bash/common-dev"

# shellcheck source=../bash/common-homebrew
. "$SCRIPT_DIR/../bash/common-homebrew"

assert_is_macos
assert_not_root

offer_sudo_password_bypass

# install Homebrew if needed
brew_check

# don't force a "brew update" -- Homebrew does this often enough automatically
brew_mark_cache_clean

# add any missing taps
brew_check_taps

brew_queue_formulae "prerequisites" "\
 coreutils\
 gawk\
 gnu-sed\
 grep\
 lftp\
 msmtp\
 node@8\
 pv\
 python\
 python@2\
 rsync\
 s-nail\
 telnet\
 unison\
 wget\
" N

brew_process_queue

if brew_formula_just_installed 'node@8' || ! command_exists npm; then

    brew link --force node@8

fi

brew_queue_formulae "essentials" "\
 exiftool\
 imagemagick\
 openconnect\
 youtube-dl\
"

# 2019-10-03: copyq removed due to macOS bugs (last known "good" version: 3.7.2)
brew_queue_casks "desktop essentials" "\
 acorn\
 balenaetcher\
 firefox\
 geekbench\
 google-chrome\
 handbrake\
 iterm2\
 karabiner-elements\
 keepassxc\
 keepingyouawake\
 libreoffice\
 makemkv\
 mkvtoolnix\
 owncloud\
 pencil\
 scribus\
 skype\
 stretchly\
 subler\
 sublime-text\
 synergy\
 the-unarchiver\
 transmission\
 typora\
 vlc\
"

brew_queue_casks "proprietary essentials" "\
 anylist\
 caprine\
 microsoft-teams\
 rescuetime\
 slack\
 sonos\
 spotify\
 twist\
"

brew_queue_casks "Microsoft Office" "microsoft-office"

# ghostscript: PDF/PostScript processor
# pandoc: text conversion tool (e.g. Markdown to PDF)
# poppler: PDF tools like pdfimages
brew_queue_formulae "PDF tools" "\
 ghostscript\
 pandoc\
 poppler\
"

if brew_formula_installed_or_queued "pandoc"; then

    brew_queue_casks "PDF tools" "\
 basictex\
" N

fi

brew_queue_formulae "OCR tools" "\
 ocrmypdf\
 tesseract\
 tesseract-lang\
"

brew_queue_casks "photography" "\
 adobe-dng-converter\
 displaycal\
 imageoptim\
"

brew_queue_formulae "development" "\
 ant\
 autoconf\
 cmake\
 gradle\
 php@7.2\
 pkg-config\
"

# TODO: remove composer

brew_queue_casks "development" "\
 android-studio\
 db-browser-for-sqlite\
 dbeaver-community\
 hex-fiend\
 lingon-x\
 postman\
 sequel-pro\
 sourcetree\
 sublime-merge\
 visual-studio-code\
"

brew_queue_formulae "development services" "\
 mariadb\
 mongodb/brew/mongodb-community@4.0\
"

brew_queue_casks "PowerShell" "powershell"

brew_queue_casks "VirtualBox" "\
 virtualbox\
 virtualbox-extension-pack\
"

brew_queue_casks "Brother P-touch Editor" "\
 brother-p-touch-editor\
 brother-p-touch-update-software\
"

dev_install_packages Y BREW_INSTALLED

brew_process_queue

DEV_JUST_INSTALLED=()
dev_process_queue DEV_JUST_INSTALLED

if [ "${#DEV_JUST_INSTALLED[@]}" -gt "0" ]; then

    BREW_INSTALLED+=("${DEV_JUST_INSTALLED[@]}")
    BREW_JUST_INSTALLED+=("${DEV_JUST_INSTALLED[@]}")

fi

# TODO (and same on system update):
# sudo tlmgr update --self && sudo tlmgr install collection-fontsrecommended || die
# luaotfload-tool --update || die

dev_apply_system_config

"$ROOT_DIR/bash/dev-system-update.sh"
