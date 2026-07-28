# Architecture

## Design

Everything lives in a single script, [RecycleBinParser.ps1](../RecycleBinParser.ps1), for easy drop-in use. Functions are defined at the top; the live scan runs only when the script is **executed**, not when it is **dot-sourced** (so Pester can load helpers without scanning the machine).

## Flow

1. Resolve scan roots (`-Path`, `-Drive`, or all PSDrives).
2. Find `$I*` files under each root.
3. Parse `$I` by format version.
4. Pair with sibling `$R*` file.
5. Collect anomalies and emit CSV or list output.

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

For `$I<suffix>`, the content file is `$R<suffix>` in the same directory.

## Anomalies

| Flag | Meaning |
|------|---------|
| `ModificationTimeMismatch` | `$I` LastWriteTime ≠ deletion local time (second precision) |
| `RFileMissing` | Matching `$R` not found |
| `SizeMismatch` | `$R` length ≠ metadata file size |
| `PathLengthMismatch` | Early NUL inside the v2 declared path region |
| `UnknownSid` | SID folder invalid or could not be translated |

## Tests

Synthetic `$I` bytes are built by [tests/New-IFileFixture.ps1](../tests/New-IFileFixture.ps1). Pester cases live in [tests/RecycleBinParser.Tests.ps1](../tests/RecycleBinParser.Tests.ps1).
