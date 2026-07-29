# Contributing

## Scope

Get-RecycleBinItem is intentionally a **single** PowerShell script plus docs and tests. Prefer small, focused changes.

## Development

1. Edit `Get-RecycleBinItem.ps1`.
2. Add or update Pester tests under `tests/`.
3. Run `Invoke-Pester -Path .\tests`.
4. Update `CHANGELOG.md` and docs when behavior changes.

## Style

- Keep comment-based help accurate (`Get-Help .\Get-RecycleBinItem.ps1 -Full`).
- Use `Write-Verbose` for skip/diagnostic detail; do not fail the whole run on one bad `$I` file.
- Non-admin use must keep working for the current user's Recycle Bin.
- Prefer approved PowerShell Verb-Noun names for functions.

## License

Contributions are under the Mozilla Public License 2.0 (see [LICENSE](LICENSE)).
