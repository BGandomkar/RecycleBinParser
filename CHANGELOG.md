# Changelog

All notable changes to this project are documented in this file.

## [1.3.0] - 2026-07-29

### Added

- `-AnomaliesOnly` switch to return only items with a non-empty `Anomalies` field

## [1.2.0] - 2026-07-29

### Changed

- Renamed tool from RecycleBinParser to **Get-RecycleBinItem** (script and docs)
- Renamed functions to Verb-Noun style: `Get-RecycleBinItem`, `ConvertFrom-RecycleBinIFile`, `Resolve-RecycleBinDataPath`, `Resolve-RecycleBinSid`, `Get-RecycleBinRoot`

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
