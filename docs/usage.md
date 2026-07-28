# Usage

```powershell
Get-Help .\RecycleBinParser.ps1 -Full
```

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-CsvPath` | Write results to CSV. Without it, output uses `Format-List`. |
| `-Drive` | Scan only one volume (e.g. `C` or `C:`). |
| `-Path` | Scan a specific `$RECYCLE.BIN` tree (live or offline copy). |
| `-Verbose` | Log skipped/corrupt files and scan roots. |

`-Drive` and `-Path` are mutually exclusive. Default (neither set) scans all filesystem PSDrives that have `$RECYCLE.BIN`.

## Examples

```powershell
# All drives, console output
.\RecycleBinParser.ps1

# One drive + CSV
.\RecycleBinParser.ps1 -Drive C -CsvPath C:\temp\recycle.csv

# Offline evidence tree
.\RecycleBinParser.ps1 -Path D:\evidence\`$RECYCLE.BIN -Verbose
```

## Elevation

If you are not elevated, the script warns and continues. You can still parse your own Recycle Bin SID folder; other users' folders may be denied.

## Output fields

Includes `FormatVersion`, size and deletion times, original path, SID/user, `$R` path/existence/size, and `Anomalies` (comma-separated flags).
