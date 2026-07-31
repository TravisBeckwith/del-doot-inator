# del-doot-inator

*"Behold, the Del-Doot-inator! It del-doots ALL your caches!"*

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
[![DOI](https://zenodo.org/badge/1289484775.svg)](https://doi.org/10.5281/zenodo.21197519)

A companion to [updoot-inator](https://github.com/TravisBeckwith/updoot-inator). Removes cached downloads and leftover files left behind by package managers after updates or installations. Does **not** remove installed packages.

## Install

```bash
git clone https://github.com/TravisBeckwith/del-doot-inator.git
cd del-doot-inator
bash ./install.sh
```

Or manually:

```bash
git clone https://github.com/TravisBeckwith/del-doot-inator.git
cd del-doot-inator
sudo install -m 0755 del-doot-inator.sh /usr/local/bin/del-doot-inator
```

## Usage

```bash
# Clean everything (standard)
del-doot-inator

# Preview what would be removed and estimated space freed
del-doot-inator --dry-run

# Deep clean (see Aggressive Mode below)
del-doot-inator --aggressive

# Interactive mode — prompt before each manager
del-doot-inator --interactive

# Only clean specific managers
del-doot-inator --only apt,pip

# Skip specific managers
del-doot-inator --skip conda,npm

# Log output to file
del-doot-inator --log ~/cleanup.log

# List detected package managers
del-doot-inator --list
```

## Options

| Option | Description |
| --- | --- |
| `-h, --help` | Show help message |
| `-v, --version` | Show version |
| `-n, --dry-run` | Show what would be removed without deleting anything |
| `-a, --aggressive` | Deeper clean (see below) |
| `-i, --interactive` | Prompt before each manager |
| `-V, --verbose` | Show detailed command output |
| `-l, --log <file>` | Log output to a file |
| `-o, --only <list>` | Only clean specified managers (comma-separated) |
| `-s, --skip <list>` | Skip specified managers (comma-separated) |
| `-L, --list` | List detected package managers |
| `--no-color` | Disable colored output |

## Supported Package Managers

| Manager | Standard clean | Aggressive clean (`-a`) |
| --- | --- | --- |
| apt | `apt clean` — removes all `.deb` files from the package cache | Same |
| brew | `brew cleanup` — removes old versions and downloads older than 120 days | `brew cleanup --prune=all` — removes everything regardless of age |
| pip / pip3 | `pip cache purge` — removes all cached wheels and HTTP data | Same |
| conda | `conda clean --tarballs` — removes downloaded `.tar.bz2` / `.conda` files | `conda clean --all` — also removes index cache, package cache, and lock files |
| npm | `npm cache clean --force` — clears entire npm cache | Same |
| cargo | `cargo cache --autoclean` — removes stale registry entries (requires `cargo-cache`) | `cargo cache --remove-dir all` — removes entire registry and git source cache |
| snap | Removes all disabled (old) revisions; warns and skips any that can't be stopped | Same |
| flatpak | Removes user and system download caches | Also runs `flatpak uninstall --unused` to remove unused runtimes and extensions |
| firmware | `fwupdmgr clear-history` — clears firmware update history and cached downloads | Same |

### cargo-cache

The cargo cleaner requires the `cargo-cache` crate. If it's not installed, del-doot-inator will warn and skip. Install it with:

```bash
cargo install cargo-cache
```

## Aggressive Mode

`--aggressive` is safe — it will never remove installed packages — but it clears more cached data, which means slower downloads or builds next time those caches are needed. Use it when you're low on disk space and don't mind waiting a bit longer on the next `updoot-inator` run.

## Uninstall

```bash
bash ./uninstall.sh
```

## Updating

```bash
cd del-doot-inator
git pull
bash ./install.sh
```

## Release Notes

**Fixed**
- **Incomplete dry-run summary**: `--dry-run` only listed `snap` and `flatpak` in the final "Cleaned:" summary — the other 7 cleaners (apt, brew, pip, conda, npm, cargo, firmware) reported their planned actions inline during the run but never surfaced them in the end-of-run summary. This meant `--dry-run`'s own stated purpose ("estimated space freed") wasn't actually reflected in the summary for most package managers. All 9 cleaners now report consistently, with cache size where available (e.g. `apt (8.0K, dry-run)`, `pip (684M, dry-run)`).
- **Predictable temp file path in `clean_snap()`**: `snap remove`'s stderr was captured to a fixed, shared path (`/tmp/snap_err`) — a minor hardening gap on multi-user systems (symlink/race susceptibility). Switched to `mktemp` with a function-scoped cleanup trap.

See [Changelog.md](Changelog.md) for the full version history.

## Companion Tool

Pair with [updoot-inator](https://github.com/TravisBeckwith/updoot-inator) for a full update-then-clean workflow:

```bash
updoot-inator && del-doot-inator
```
