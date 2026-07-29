# Architecture

## Design

Everything lives in a single script, [Get-RecycleBinItem.ps1](../Get-RecycleBinItem.ps1), for easy drop-in use. Functions are defined at the top; the live scan runs only when the script is **executed**, not when it is **dot-sourced** (so Pester can load helpers without scanning the machine).

## Flow

1. Resolve scan roots (`-Path`, `-Drive`, or all PSDrives) via `Get-RecycleBinRoot`.
2. Find `$I*` files under each root.
3. Parse `$I` by format version (`ConvertFrom-RecycleBinIFile`).
4. Find sibling `$R*` on disk (`Find-RecycleBinDataItem`).
5. Collect anomalies and emit CSV or list output (`Get-RecycleBinItem`).

## `$I` formats

Shared header:

| Offset | Size | Field |
|--------|------|-------|
| 0 | 8 | Format version (`1` or `2`) |
| 8 | 8 | Original file size |
| 16 | 8 | Deletion FILETIME (UTC) |

**Version 1** (Vista–8.1): UTF-16LE path at offset 24, typically within a 544-byte file (520-byte path slot, NUL-padded).

**Version 2** (Windows 10+): `UInt32` path character count (including NUL) at offset 24; path bytes at offset 28. Length is bounds-checked against file size.

Unknown versions are skipped (`Write-Verbose`).

## `$I` / `$R` pairing

For `$I<suffix>`, `Find-RecycleBinDataItem` lists the `$I` directory and looks for an on-disk item named `$R<suffix>` (file or directory). `RecycleDataFile` is set only when that item is found; otherwise it is empty and `RFileMissing` is flagged.

## FileType

`Get-RecycleBinFileType` sets `FileType` as:

1. `directory` if `$R` exists as a container
2. Otherwise the lowercase extension from `OriginalPath` (e.g. `pdf`, `exe`)
3. `unknown` if there is no extension

## Anomalies

| Flag | Meaning |
|------|---------|
| `ModificationTimeMismatch` | `$I` LastWriteTime ≠ deletion local time (second precision) |
| `RFileMissing` | Matching `$R` not found (file or directory) |
| `SizeMismatch` | `$R` **file** length ≠ metadata file size (not applied to directories) |
| `PathLengthMismatch` | Early NUL inside the v2 declared path region |
| `UnknownSid` | SID folder invalid or could not be translated |

## Tests

Synthetic `$I` bytes are built by [tests/New-IFileFixture.ps1](../tests/New-IFileFixture.ps1). Pester cases live in [tests/Get-RecycleBinItem.Tests.ps1](../tests/Get-RecycleBinItem.Tests.ps1).
