# Usage

```powershell
Get-Help .\Get-RecycleBinItem.ps1 -Full
```

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-CsvPath` | Write results to CSV. Without it, PSCustomObject items go to the pipeline (console auto-formats them). |
| `-Drive` | Scan only one volume (e.g. `C` or `C:`). |
| `-Path` | Scan a specific `$RECYCLE.BIN` tree (live or offline copy). |
| `-AnomaliesOnly` | Return only items with a non-empty `Anomalies` value. |
| `-Verbose` | Log skipped/corrupt files and scan roots. |

`-Drive` and `-Path` are mutually exclusive. Default (neither set) scans all filesystem PSDrives that have `$RECYCLE.BIN`.

## Examples

```powershell
# All drives, console output
.\Get-RecycleBinItem.ps1

# One drive + CSV
.\Get-RecycleBinItem.ps1 -Drive C -CsvPath C:\temp\recycle.csv

# Offline evidence tree
.\Get-RecycleBinItem.ps1 -Path D:\evidence\`$RECYCLE.BIN -Verbose

# Only items with anomalies
.\Get-RecycleBinItem.ps1 -AnomaliesOnly
```

## Elevation

If you are not elevated, the script warns and continues. You can still parse your own Recycle Bin SID folder; other users' folders may be denied.

## Output fields

Includes `FormatVersion`, `FileType` (extension like `pdf`/`exe`, or `directory`/`unknown`), size and deletion times, original path, SID/user, `$R` path/existence/size, and `Anomalies` (comma-separated flags).
