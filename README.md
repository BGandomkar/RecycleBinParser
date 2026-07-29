# Get-RecycleBinItem

PowerShell tool (v1.3.0) that parses Windows Recycle Bin `$I` metadata (Vista+ versions 1 and 2), pairs each entry with its `$R` content file, and reports integrity anomalies. Inspired by Eric Zimmerman's RBCmd.

**License:** [Mozilla Public License 2.0](LICENSE)

## Features

- Version-aware `$I` parsing (v1 Vista–8.1, v2 Windows 10+)
- `$I` / `$R` pairing and size checks
- Scan all drives, one `-Drive`, or a custom `-Path` (offline copy)
- Works without admin for your own Recycle Bin; warns when not elevated
- `-AnomaliesOnly` to list only flagged items
- CSV or console output; `-Verbose` for skipped files
- Pester tests with synthetic fixtures

## Usage

```powershell
.\Get-RecycleBinItem.ps1
.\Get-RecycleBinItem.ps1 -Drive C -CsvPath C:\temp\recycle.csv
.\Get-RecycleBinItem.ps1 -Path D:\evidence\`$RECYCLE.BIN -Verbose
.\Get-RecycleBinItem.ps1 -AnomaliesOnly
Get-Help .\Get-RecycleBinItem.ps1 -Full
```

## Tests

```powershell
Invoke-Pester -Path .\tests
```

## Documentation

See [docs/index.md](docs/index.md) for getting started, usage, and architecture. Contribution notes: [CONTRIBUTING.md](CONTRIBUTING.md). Changes: [CHANGELOG.md](CHANGELOG.md).

## Notes

- Deletion times come from the `$I` FILETIME (UTC and local). `RecycleFileModification` is the `$I` file's `LastWriteTime` (local).
- Emptying the Recycle Bin removes `$I`/`$R` pairs; this tool only reads what is still on disk.
