# Getting started

Get-RecycleBinItem is a single PowerShell script that parses Windows Recycle Bin `$I` metadata files (Vista+), pairs them with `$R` content files, and reports integrity anomalies.

## Quick start

1. Open PowerShell (elevated if you need other users' bins).
2. Allow script execution for the session if needed:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

3. Run:

```powershell
.\Get-RecycleBinItem.ps1
```

4. Or export CSV:

```powershell
.\Get-RecycleBinItem.ps1 -CsvPath "$env:TEMP\recycle.csv"
```

See [Installation](installation.md) and [Usage](usage.md) for details.
