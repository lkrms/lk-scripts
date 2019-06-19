# Platform-independent bash scripts and libraries

## Using common

The suggested method for sourcing `common` in your scripts is as follows:

```bash
SCRIPT_PATH="${BASH_SOURCE[0]}"
[ -L "$SCRIPT_PATH" ] && SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

. "$SCRIPT_DIR/path/to/common" || exit 1
```

If this seems unnecessarily complex, consider that:

- Using `$BASH_SOURCE` instead of `$0` ensures your script can be sourced safely
- `realpath` isn't platform-independent and `pwd -P` is only useful for directories, which leaves us with a combination of `readlink` and `pwd -P`
- `readlink` ensures your script locates itself correctly even when symlinked from another directory
- `pwd -P` resolves symbolic links between directories

