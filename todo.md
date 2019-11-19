- [ ] Check for incorrect uses of `\b` in regular expressions (word boundaries exist between letters/numbers and hyphens)
- [ ] Check all uses of `grep`, `sed` etc. and replace with `gnu_*` as needed
- [ ] Check all uses of `grep -q` for `SIGPIPE` risk
- [ ] Check for output to stderr wherever appropriate
- [ ] Replace, for example, `IS_MACOS` tests with `is_macos`
- [ ] macOS: Add SSH key loading to .bashrc
- [ ] Ensure empty arrays expand correctly on bash <=4.3

    1. Search: `(?<!\+)"\$\{([a-zA-Z0-9_]+)\[@\]\}"`  
    Replace: `${$1[@]+$0}`

    2. Search: `(?<!\+)\$\{([a-zA-Z0-9_]+)\[\*\]\}`  
    Replace: `${$1[*]+$0}`

- [ ] Add `apt-enable-sources.sh` and `apt-disable-sources.sh`

    ```bash
    # enable
    sudo gnu_sed -i 's/^# deb-src /deb-src /' /etc/apt/sources.list

    # disable
    sudo gnu_sed -i 's/^deb-src /# deb-src /' /etc/apt/sources.list
    ```

- [ ] Create script like:

    ```bash
    pushd /tmp
    mk-build-deps "$1" --install --root-cmd sudo --remove
    popd
    ```
