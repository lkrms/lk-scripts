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

brew_mark_cache_clean

# python3: so that we can use pip3 below
brew_install_formulae "essentials" "\
 coreutils\
 lftp\
 msmtp\
 pv\
 python\
 rsync\
 s-nail\
 telnet\
 wget\
" N

brew_install_formulae "desktop essentials" "\
 exiftool\
 imagemagick\
 openconnect\
 youtube-dl\
"

# ghostscript: PDF/PostScript processor
# pandoc: text conversion tool (e.g. Markdown to PDF)
# poppler: PDF tools like pdfimages
brew_install_formulae "PDF tools" "\
 ghostscript\
 pandoc\
 poppler\
"

brew_install_formulae "OCR tools" "\
 ocrmypdf\
 tesseract-lang\
 tesseract\
"

brew_process_queue

