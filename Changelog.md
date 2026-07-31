# Changelog

## [Unreleased]

### Fixed
- **Dry-run summary was incomplete for most managers.** Only `snap` and
  `flatpak` added an entry to the final "Cleaned:" summary during
  `--dry-run`; the other 7 cleaners (apt, brew, pip, conda, npm, cargo,
  firmware) reported their planned actions inline but never surfaced
  them in the end-of-run summary, so `--dry-run`'s own stated purpose
  ("estimated space freed") wasn't actually reflected there for most
  package managers. All 9 cleaners now report consistently.
- **Predictable temp file path in `clean_snap()`**: `snap remove`'s
  stderr was captured to a fixed path (`/tmp/snap_err`) shared across
  all users on the system — a minor hardening gap (symlink/race
  susceptibility on a shared `/tmp`). Switched to `mktemp` with a
  function-scoped cleanup trap.

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
