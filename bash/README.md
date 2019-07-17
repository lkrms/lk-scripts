# Platform-independent bash scripts and libraries

## Using common

The suggested method for sourcing `common` in your scripts is as follows:

```bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=path/to/bash/common
. "$SCRIPT_DIR/path/to/bash/common"
```

If this seems unnecessarily complex, consider that:

- Using `$BASH_SOURCE` instead of `$0` ensures your script can be sourced safely
- `realpath` isn't platform-independent, `pwd -P` is only useful for directories, and `readlink` isn't recursive
- `pwd -P` resolves symbolic links between directories

