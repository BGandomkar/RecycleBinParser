# Changelog

All notable changes to this project are documented in this file.

## [1.1.0] - 2026-07-28

### Added

- Version-aware `$I` parsing (format versions 1 and 2)
- `$R` pairing fields: `RecycleDataFile`, `RecycleDataExists`, `RecycleDataSize`
- CLI parameters `-Drive` and `-Path`, plus `-Verbose` via `CmdletBinding`
- Non-fatal elevation warning (non-admin users can still parse their own bin)
- Anomaly flags: `RFileMissing`, `SizeMismatch`, `PathLengthMismatch`, `UnknownSid`
- Comment-based help (`Get-Help`)
- Pester tests and `$I` fixture helper
- Documentation under `docs/`, plus `CONTRIBUTING.md`

### Changed

- Results collected with a generic list instead of array `+=`
- SID resolution matches `$RECYCLE.BIN` case-insensitively in the path

## [1.0.0] - Initial

- Scan all filesystem drives for `$I*` files and export console or CSV metadata
