$ErrorActionPreference = 'Stop'

BeforeAll {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $repoRoot 'RecycleBinParser.ps1')
    . (Join-Path $PSScriptRoot 'New-IFileFixture.ps1')
}

Describe 'ParseRecycleFile' {
    BeforeEach {
        $script:tempRoot = Join-Path $env:TEMP ("RecycleBinParserTests_" + [guid]::NewGuid().ToString('N'))
        $sidDir = Join-Path $script:tempRoot '$RECYCLE.BIN\S-1-5-21-1-2-3-1001'
        New-Item -ItemType Directory -Path $sidDir -Force | Out-Null
        $script:sidDir = $sidDir
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:tempRoot) {
            Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'parses a version 2 $I file' {
        $deleted = [datetime]::SpecifyKind([datetime]'2024-06-15T12:30:00', 'Utc')
        $fx = New-IFileFixture -Directory $script:sidDir -Name '$IABC123.txt' -Version 2 `
            -FileSize 42 -DeletionUtc $deleted -OriginalPath 'C:\Users\demo\file.txt' -CreateRFile

        $item = Get-Item -LiteralPath $fx.IPath -Force
        # Align LastWriteTime to deletion local for clean anomalies aside from pairing
        $item.LastWriteTime = $deleted.ToLocalTime()

        $parsed = ParseRecycleFile -FilePath $fx.IPath -LastModified $item.LastWriteTime

        $parsed | Should -Not -BeNullOrEmpty
        $parsed.FormatVersion | Should -Be 2
        $parsed.FileSize | Should -Be 42
        $parsed.OriginalPath | Should -Be 'C:\Users\demo\file.txt'
        $parsed.PathLength | Should -Be ('C:\Users\demo\file.txt'.Length)
        $parsed.DeletionUTCTime.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') |
            Should -Be $deleted.ToString('yyyy-MM-dd HH:mm:ss')
        $parsed.RecycleDataExists | Should -BeTrue
        $parsed.RecycleDataSize | Should -Be 42
        $parsed.Anomalies | Should -Not -Match 'RFileMissing'
        $parsed.Anomalies | Should -Not -Match 'SizeMismatch'
    }

    It 'parses a version 1 $I file' {
        $deleted = [datetime]::SpecifyKind([datetime]'2020-01-02T03:04:05', 'Utc')
        $fx = New-IFileFixture -Directory $script:sidDir -Name '$IDEF456.doc' -Version 1 `
            -FileSize 100 -DeletionUtc $deleted -OriginalPath 'D:\old\report.doc' -CreateRFile

        $item = Get-Item -LiteralPath $fx.IPath -Force
        $item.LastWriteTime = $deleted.ToLocalTime()

        $parsed = ParseRecycleFile -FilePath $fx.IPath -LastModified $item.LastWriteTime

        $parsed | Should -Not -BeNullOrEmpty
        $parsed.FormatVersion | Should -Be 1
        $parsed.FileSize | Should -Be 100
        $parsed.OriginalPath | Should -Be 'D:\old\report.doc'
        $parsed.RecycleDataExists | Should -BeTrue
    }

    It 'returns null for truncated files' {
        $deleted = [datetime]::UtcNow
        $fx = New-IFileFixture -Directory $script:sidDir -Name '$ITRUNC.bin' -Version 2 `
            -FileSize 1 -DeletionUtc $deleted -OriginalPath 'C:\a.txt' -Truncate

        $parsed = ParseRecycleFile -FilePath $fx.IPath -LastModified ([datetime]::Now)
        $parsed | Should -Be $null
    }

    It 'returns null for invalid FILETIME' {
        $path = Join-Path $script:sidDir '$IBADTIME.bin'
        $buf = New-Object byte[] 40
        [BitConverter]::GetBytes([int64]2).CopyTo($buf, 0)
        [BitConverter]::GetBytes([int64]10).CopyTo($buf, 8)
        [BitConverter]::GetBytes([int64]-1).CopyTo($buf, 16)
        [BitConverter]::GetBytes([uint32]2).CopyTo($buf, 24)
        # path: empty + NUL already zeroed
        [System.IO.File]::WriteAllBytes($path, $buf)

        $parsed = ParseRecycleFile -FilePath $path -LastModified ([datetime]::Now)
        $parsed | Should -Be $null
    }

    It 'returns null for v2 path length overflow' {
        $deleted = [datetime]::UtcNow
        $fx = New-IFileFixture -Directory $script:sidDir -Name '$IOVER.bin' -Version 2 `
            -FileSize 1 -DeletionUtc $deleted -OriginalPath 'C:\a.txt' -OverridePathCharCount 5000

        # OverridePathCharCount makes declared size huge; WriteAllBytes still writes small buffer
        # Rebuild as truncated relative to claim: helper allocates charCount*2 so file is large.
        # Instead write a small file claiming a large length:
        $buf = New-Object byte[] 32
        [BitConverter]::GetBytes([int64]2).CopyTo($buf, 0)
        [BitConverter]::GetBytes([int64]1).CopyTo($buf, 8)
        [BitConverter]::GetBytes($deleted.ToFileTimeUtc()).CopyTo($buf, 16)
        [BitConverter]::GetBytes([uint32]400).CopyTo($buf, 24)
        [System.IO.File]::WriteAllBytes($fx.IPath, $buf)

        $parsed = ParseRecycleFile -FilePath $fx.IPath -LastModified ([datetime]::Now)
        $parsed | Should -Be $null
    }

    It 'flags RFileMissing when $R is absent' {
        $deleted = [datetime]::SpecifyKind([datetime]'2024-01-01T00:00:00', 'Utc')
        $fx = New-IFileFixture -Directory $script:sidDir -Name '$INOR.bin' -Version 2 `
            -FileSize 5 -DeletionUtc $deleted -OriginalPath 'C:\x.bin'

        $item = Get-Item -LiteralPath $fx.IPath -Force
        $item.LastWriteTime = $deleted.ToLocalTime()

        $parsed = ParseRecycleFile -FilePath $fx.IPath -LastModified $item.LastWriteTime
        $parsed.RecycleDataExists | Should -BeFalse
        $parsed.Anomalies | Should -Match 'RFileMissing'
    }

    It 'flags SizeMismatch when $R length differs' {
        $deleted = [datetime]::SpecifyKind([datetime]'2024-01-01T00:00:00', 'Utc')
        $fx = New-IFileFixture -Directory $script:sidDir -Name '$ISIZE.bin' -Version 2 `
            -FileSize 10 -DeletionUtc $deleted -OriginalPath 'C:\y.bin' -CreateRFile -RFileSize 3

        $item = Get-Item -LiteralPath $fx.IPath -Force
        $item.LastWriteTime = $deleted.ToLocalTime()

        $parsed = ParseRecycleFile -FilePath $fx.IPath -LastModified $item.LastWriteTime
        $parsed.Anomalies | Should -Match 'SizeMismatch'
    }

    It 'flags PathLengthMismatch when an early NUL appears in the v2 path region' {
        $deleted = [datetime]::SpecifyKind([datetime]'2024-01-01T00:00:00', 'Utc')
        $original = 'C:\early'
        # Build valid v2 then plant an early NUL after first two chars ("C:")
        $fx = New-IFileFixture -Directory $script:sidDir -Name '$IEARLY.bin' -Version 2 `
            -FileSize 1 -DeletionUtc $deleted -OriginalPath $original -CreateRFile

        $bytes = [System.IO.File]::ReadAllBytes($fx.IPath)
        # Offset 28 = 'C', 30 = ':', 32 = '\' -> put NUL at index 32
        $bytes[32] = 0
        $bytes[33] = 0
        [System.IO.File]::WriteAllBytes($fx.IPath, $bytes)

        $item = Get-Item -LiteralPath $fx.IPath -Force
        $item.LastWriteTime = $deleted.ToLocalTime()

        $parsed = ParseRecycleFile -FilePath $fx.IPath -LastModified $item.LastWriteTime
        $parsed | Should -Not -BeNullOrEmpty
        $parsed.Anomalies | Should -Match 'PathLengthMismatch'
    }
}

Describe 'Get-RecycleDataPath' {
    It 'maps $I name to $R sibling' {
        $p = Get-RecycleDataPath -IFilePath 'C:\$RECYCLE.BIN\S-1-5-21-1-2-3-4\$IABCDEF.txt'
        $p | Should -Be 'C:\$RECYCLE.BIN\S-1-5-21-1-2-3-4\$RABCDEF.txt'
    }
}

Describe 'Get-RecycleBinRoots' {
    It 'resolves -Path to an existing directory' {
        $dir = Join-Path $env:TEMP ("RecycleRoots_" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $roots = Get-RecycleBinRoots -Path $dir
            $roots.Count | Should -Be 1
            $roots[0] | Should -Be (Resolve-Path -LiteralPath $dir).Path
        } finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
