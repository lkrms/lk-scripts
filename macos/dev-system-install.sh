#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

# shellcheck source=../bash/common-dev
. "$SCRIPT_DIR/../bash/common-dev"

assert_is_macos
assert_not_root

offer_sudo_password_bypass

# included later because it installs Homebrew if needed
# shellcheck source=../bash/common-homebrew
. "$SCRIPT_DIR/../bash/common-homebrew"

# don't force a "brew update" -- Homebrew does this often enough automatically
brew_mark_cache_clean

# add any missing taps
brew_check_taps

brew_queue_formulae "prerequisites" "\
 coreutils\
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

brew_queue_casks "desktop essentials" "\
 acorn\
 balenaetcher\
 copyq\
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
 mongodb\
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

brew_process_queue

# TODO:
# sudo tlmgr update --self && sudo tlmgr install collection-fontsrecommended || die
# luaotfload-tool --update || die

dev_apply_system_config
