- [ ] Check for incorrect uses of `\b` in regular expressions (word boundaries exist between letters/numbers and hyphens)
- [ ] Check all uses of `grep`, `sed` etc. and replace with `gnu_*` as needed
- [ ] Check all uses of `grep -q` for `SIGPIPE` risk
- [ ] Check for output to stderr wherever appropriate
- [ ] Replace, for example, `IS_MACOS` tests with `is_macos`
- [ ] macOS: Add SSH key loading to .bashrc
- [ ] Ensure empty arrays expand correctly on bash <=4.3

        (?<!\+)"\$\{([a-zA-Z0-9_]+)\[@\]\}"
        ${$1[@]+$0}

        (?<!\+)\$\{([a-zA-Z0-9_]+)\[\*\]\}
        ${$1[*]+$0}
