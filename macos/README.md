## To enforce RGB mode on external monitors

This may resolve issues with colours appearing washed out, display artefacts, screen flickering, etc.

1. Run `monitor-patch-edid.rb` with the monitors connected. The necessary files will be generated in your working directory within one or more `DisplayVendorID-xxxx` folders.
2. Reboot into macOS Recovery (press and hold ⌘-R during startup).
3. Use Terminal to copy the relevant folders to `/System/Library/Displays/Contents/Resources/Overrides/`. Your system drive will most likely be mounted at `/Volumes/Macintosh HD`.
4. Reboot.

