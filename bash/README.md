# Bash scripts and libraries

## Using common

The suggested method for sourcing `common` in your Bash scripts is as follows:

```bash
#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/path/to/bash/common"
```

If this seems unnecessarily complex, consider that:

- `set -euo pipefail` makes `bash` exit straightaway if a command fails (`-e`), even if the command that failed wasn't last in a pipeline (`-o pipefail`). It also makes `bash` treat expansion of unset variables and parameters as errors (`-u`).

    In other words, it makes `bash` significantly more robust, as long as you're aware of caveats (some would say flaws) like:

    - You can't rely on `-e` in functions that may be called in a subshell or command substitution (`-e` isn't inherited by subshells) or within a test (e.g. `if my_function; then` or `myfunction || true`).

- `realpath` isn't platform-independent, `pwd -P` is only useful for directories, and `readlink` isn't recursive, POSIX-compliant, or consistent between platforms.

    Given `python` is usually available when `realpath` isn't (e.g. on macOS), resolving the path to your script with `realpath`, and trying Python's `os.path.realpath` if `realpath` fails, is an **imperfect but reasonably portable** way of allowing for file and/or directory symlinks.

    Achieving the same result without relying on anything except `bash` builtins and POSIX utilities is possible but requires significantly more code. It's even worse if you need POSIX shell compliance.

- Using `$BASH_SOURCE` instead of `$0` ensures your script can be sourced safely.
