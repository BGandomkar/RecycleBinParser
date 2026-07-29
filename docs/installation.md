# Installation

## Requirements

- Windows with PowerShell 5.1 or PowerShell 7+
- Permission to read `$RECYCLE.BIN` (your own SID folder works without admin; other users usually need elevation)

## Install

Clone or copy the repository. The tool is one script:

```text
Get-RecycleBinItem.ps1
```

No module install is required.

## Tests (optional)

Install [Pester](https://pester.dev/) 5+, then from the repo root:

```powershell
Invoke-Pester -Path .\tests
```

## License

Mozilla Public License 2.0 — see [LICENSE](../LICENSE).
