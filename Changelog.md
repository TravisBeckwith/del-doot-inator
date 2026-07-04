# Changelog

## [1.0.0] - 2026-07-04

### Features
- Initial release 🗑️💀
- Cache and download cleanup for apt, brew, pip/pip3, conda, npm, cargo, snap, flatpak, firmware
- Standard clean: removes only safely-regenerable cached downloads
- Aggressive mode (`--aggressive`): deeper clean that trades disk space for slower next operations
- Dry-run mode: reports what would be removed and estimated space freed before touching anything
- Interactive mode: prompt before each manager
- Verbose output
- Logging to file
- Filter by `--only` and `--skip`
- Colorized output with `--no-color` option
- Per-manager before/after size reporting
- Warn-and-skip for snap revisions that cannot be removed (in-use or cannot be stopped)
- PEP 668-aware pip handling (consistent with updoot-inator)
