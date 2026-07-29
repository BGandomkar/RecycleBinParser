$ErrorActionPreference = 'Stop'

BeforeAll {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $repoRoot 'Get-RecycleBinItem.ps1')
    . (Join-Path $PSScriptRoot 'New-IFileFixture.ps1')
}

Describe 'ConvertFrom-RecycleBinIFile' {
    BeforeEach {
        $script:tempRoot = Join-Path $env:TEMP ("Get-RecycleBinItemTests_" + [guid]::NewGuid().ToString('N'))
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
        $item.LastWriteTime = $deleted.ToLocalTime()

        $parsed = ConvertFrom-RecycleBinIFile -FilePath $fx.IPath -LastModified $item.LastWriteTime

        $parsed | Should -Not -BeNullOrEmpty
        $parsed.FormatVersion | Should -Be 2
        $parsed.FileSize | Should -Be 42
        $parsed.OriginalPath | Should -Be 'C:\Users\demo\file.txt'
        $parsed.FileType | Should -Be 'txt'
        $parsed.PathLength | Should -Be ('C:\Users\demo\file.txt'.Length)
        $parsed.DeletionUTCTime.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') |
            Should -Be $deleted.ToString('yyyy-MM-dd HH:mm:ss')
        $parsed.RecycleDataExists | Should -BeTrue
        $parsed.RecycleDataSize | Should -Be 42
        $parsed.RecycleDataFile | Should -Be $fx.RPath
        $parsed.Anomalies | Should -Not -Match 'RFileMissing'
        $parsed.Anomalies | Should -Not -Match 'SizeMismatch'
    }

    It 'parses a version 1 $I file' {
        $deleted = [datetime]::SpecifyKind([datetime]'2020-01-02T03:04:05', 'Utc')
        $fx = New-IFileFixture -Directory $script:sidDir -Name '$IDEF456.doc' -Version 1 `
            -FileSize 100 -DeletionUtc $deleted -OriginalPath 'D:\old\report.doc' -CreateRFile

        $item = Get-Item -LiteralPath $fx.IPath -Force
        $item.LastWriteTime = $deleted.ToLocalTime()

        $parsed = ConvertFrom-RecycleBinIFile -FilePath $fx.IPath -LastModified $item.LastWriteTime

        $parsed | Should -Not -BeNullOrEmpty
        $parsed.FormatVersion | Should -Be 1
        $parsed.FileSize | Should -Be 100
        $parsed.OriginalPath | Should -Be 'D:\old\report.doc'
        $parsed.FileType | Should -Be 'doc'
        $parsed.RecycleDataExists | Should -BeTrue
    }

    It 'sets FileType from extension for pdf and exe paths' {
        $deleted = [datetime]::SpecifyKind([datetime]'2024-06-15T12:30:00', 'Utc')
        $pdf = New-IFileFixture -Directory $script:sidDir -Name '$IPDF001.pdf' -Version 2 `
            -FileSize 10 -DeletionUtc $deleted -OriginalPath 'C:\docs\Report.PDF' -CreateRFile
        $exe = New-IFileFixture -Directory $script:sidDir -Name '$IEXE001.exe' -Version 2 `
            -FileSize 10 -DeletionUtc $deleted -OriginalPath 'C:\tools\App.EXE' -CreateRFile

        $pdfItem = Get-Item -LiteralPath $pdf.IPath -Force
        $pdfItem.LastWriteTime = $deleted.ToLocalTime()
        $exeItem = Get-Item -LiteralPath $exe.IPath -Force
        $exeItem.LastWriteTime = $deleted.ToLocalTime()

        $pdfParsed = ConvertFrom-RecycleBinIFile -FilePath $pdf.IPath -LastModified $pdfItem.LastWriteTime
        $exeParsed = ConvertFrom-RecycleBinIFile -FilePath $exe.IPath -LastModified $exeItem.LastWriteTime

        $pdfParsed.FileType | Should -Be 'pdf'
        $exeParsed.FileType | Should -Be 'exe'
    }

    It 'sets FileType to directory when $R is a folder and does not flag RFileMissing' {
        $deleted = [datetime]::SpecifyKind([datetime]'2024-06-15T12:30:00', 'Utc')
        $fx = New-IFileFixture -Directory $script:sidDir -Name '$IDIR001' -Version 2 `
            -FileSize 0 -DeletionUtc $deleted -OriginalPath 'C:\Users\demo\MyFolder'
        $rName = '$R' + '$IDIR001'.Substring(2)
        $rPath = Join-Path $script:sidDir $rName
        New-Item -ItemType Directory -Path $rPath -Force | Out-Null

        $item = Get-Item -LiteralPath $fx.IPath -Force
        $item.LastWriteTime = $deleted.ToLocalTime()

        $parsed = ConvertFrom-RecycleBinIFile -FilePath $fx.IPath -LastModified $item.LastWriteTime
        $parsed.FileType | Should -Be 'directory'
        $parsed.RecycleDataExists | Should -BeTrue
        $parsed.RecycleDataFile | Should -Be (Get-Item -LiteralPath $rPath).FullName
        $parsed.Anomalies | Should -Not -Match 'RFileMissing'
        $parsed.Anomalies | Should -Not -Match 'SizeMismatch'
    }

    It 'sets FileType to unknown when path has no extension' {
        $deleted = [datetime]::SpecifyKind([datetime]'2024-06-15T12:30:00', 'Utc')
        $fx = New-IFileFixture -Directory $script:sidDir -Name '$INOEXT' -Version 2 `
            -FileSize 1 -DeletionUtc $deleted -OriginalPath 'C:\readme' -CreateRFile
        $item = Get-Item -LiteralPath $fx.IPath -Force
        $item.LastWriteTime = $deleted.ToLocalTime()

        $parsed = ConvertFrom-RecycleBinIFile -FilePath $fx.IPath -LastModified $item.LastWriteTime
        $parsed.FileType | Should -Be 'unknown'
    }

    It 'returns null for truncated files' {
        $deleted = [datetime]::UtcNow
        $fx = New-IFileFixture -Directory $script:sidDir -Name '$ITRUNC.bin' -Version 2 `
            -FileSize 1 -DeletionUtc $deleted -OriginalPath 'C:\a.txt' -Truncate

        $parsed = ConvertFrom-RecycleBinIFile -FilePath $fx.IPath -LastModified ([datetime]::Now)
        $parsed | Should -Be $null
    }

    It 'returns null for invalid FILETIME' {
        $path = Join-Path $script:sidDir '$IBADTIME.bin'
        $buf = New-Object byte[] 40
        [BitConverter]::GetBytes([int64]2).CopyTo($buf, 0)
        [BitConverter]::GetBytes([int64]10).CopyTo($buf, 8)
        [BitConverter]::GetBytes([int64]-1).CopyTo($buf, 16)
        [BitConverter]::GetBytes([uint32]2).CopyTo($buf, 24)
        [System.IO.File]::WriteAllBytes($path, $buf)

        $parsed = ConvertFrom-RecycleBinIFile -FilePath $path -LastModified ([datetime]::Now)
        $parsed | Should -Be $null
    }

    It 'returns null for v2 path length overflow' {
        $deleted = [datetime]::UtcNow
        $fx = New-IFileFixture -Directory $script:sidDir -Name '$IOVER.bin' -Version 2 `
            -FileSize 1 -DeletionUtc $deleted -OriginalPath 'C:\a.txt' -OverridePathCharCount 5000

        $buf = New-Object byte[] 32
        [BitConverter]::GetBytes([int64]2).CopyTo($buf, 0)
        [BitConverter]::GetBytes([int64]1).CopyTo($buf, 8)
        [BitConverter]::GetBytes($deleted.ToFileTimeUtc()).CopyTo($buf, 16)
        [BitConverter]::GetBytes([uint32]400).CopyTo($buf, 24)
        [System.IO.File]::WriteAllBytes($fx.IPath, $buf)

        $parsed = ConvertFrom-RecycleBinIFile -FilePath $fx.IPath -LastModified ([datetime]::Now)
        $parsed | Should -Be $null
    }

    It 'flags RFileMissing when $R is absent' {
        $deleted = [datetime]::SpecifyKind([datetime]'2024-01-01T00:00:00', 'Utc')
        $fx = New-IFileFixture -Directory $script:sidDir -Name '$INOR.bin' -Version 2 `
            -FileSize 5 -DeletionUtc $deleted -OriginalPath 'C:\x.bin'

        $item = Get-Item -LiteralPath $fx.IPath -Force
        $item.LastWriteTime = $deleted.ToLocalTime()

        $parsed = ConvertFrom-RecycleBinIFile -FilePath $fx.IPath -LastModified $item.LastWriteTime
        $parsed.RecycleDataExists | Should -BeFalse
        $parsed.RecycleDataFile | Should -Be ''
        $parsed.Anomalies | Should -Match 'RFileMissing'
    }

    It 'flags SizeMismatch when $R length differs' {
        $deleted = [datetime]::SpecifyKind([datetime]'2024-01-01T00:00:00', 'Utc')
        $fx = New-IFileFixture -Directory $script:sidDir -Name '$ISIZE.bin' -Version 2 `
            -FileSize 10 -DeletionUtc $deleted -OriginalPath 'C:\y.bin' -CreateRFile -RFileSize 3

        $item = Get-Item -LiteralPath $fx.IPath -Force
        $item.LastWriteTime = $deleted.ToLocalTime()

        $parsed = ConvertFrom-RecycleBinIFile -FilePath $fx.IPath -LastModified $item.LastWriteTime
        $parsed.Anomalies | Should -Match 'SizeMismatch'
    }

    It 'flags PathLengthMismatch when an early NUL appears in the v2 path region' {
        $deleted = [datetime]::SpecifyKind([datetime]'2024-01-01T00:00:00', 'Utc')
        $original = 'C:\early'
        $fx = New-IFileFixture -Directory $script:sidDir -Name '$IEARLY.bin' -Version 2 `
            -FileSize 1 -DeletionUtc $deleted -OriginalPath $original -CreateRFile

        $bytes = [System.IO.File]::ReadAllBytes($fx.IPath)
        $bytes[32] = 0
        $bytes[33] = 0
        [System.IO.File]::WriteAllBytes($fx.IPath, $bytes)

        $item = Get-Item -LiteralPath $fx.IPath -Force
        $item.LastWriteTime = $deleted.ToLocalTime()

        $parsed = ConvertFrom-RecycleBinIFile -FilePath $fx.IPath -LastModified $item.LastWriteTime
        $parsed | Should -Not -BeNullOrEmpty
        $parsed.Anomalies | Should -Match 'PathLengthMismatch'
    }
}

Describe 'Format-ByteSize' {
    It 'formats bytes, KB, MB, and GB' {
        Format-ByteSize -Bytes 512 | Should -Be '512 B'
        Format-ByteSize -Bytes 2048 | Should -Be '2 KB'
        Format-ByteSize -Bytes 1572864 | Should -Be '1.5 MB'
        Format-ByteSize -Bytes 2147483648 | Should -Be '2 GB'
    }

    It 'returns null for null input' {
        Format-ByteSize -Bytes $null | Should -Be $null
    }
}

Describe 'Get-RecycleBinItem -HumanReadableSize' {
    It 'formats FileSize and RecycleDataSize as human-readable strings' {
        $tempRoot = Join-Path $env:TEMP ("Get-RecycleBinItemHuman_" + [guid]::NewGuid().ToString('N'))
        $recycleRoot = Join-Path $tempRoot '$RECYCLE.BIN'
        $sidDir = Join-Path $recycleRoot 'S-1-5-18'
        New-Item -ItemType Directory -Path $sidDir -Force | Out-Null
        try {
            $deleted = [datetime]::SpecifyKind([datetime]'2024-03-01T10:00:00', 'Utc')
            $fx = New-IFileFixture -Directory $sidDir -Name '$IHUMAN.bin' -Version 2 `
                -FileSize 1536 -DeletionUtc $deleted -OriginalPath 'C:\human.bin' -CreateRFile
            $item = Get-Item -LiteralPath $fx.IPath -Force
            $item.LastWriteTime = $deleted.ToLocalTime()

            $raw = Get-RecycleBinItem -Path $recycleRoot
            $human = Get-RecycleBinItem -Path $recycleRoot -HumanReadableSize

            $raw[0].FileSize | Should -Be 1536
            $human[0].FileSize | Should -Be '1.5 KB'
            $human[0].RecycleDataSize | Should -Be '1.5 KB'
        } finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Find-RecycleBinDataItem' {
    It 'returns the on-disk $R item when present' {
        $dir = Join-Path $env:TEMP ("FindR_" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $iPath = Join-Path $dir '$IABCDEF.txt'
            $rPath = Join-Path $dir '$RABCDEF.txt'
            Set-Content -LiteralPath $iPath -Value 'i'
            Set-Content -LiteralPath $rPath -Value 'r'
            $found = Find-RecycleBinDataItem -IFilePath $iPath
            $found | Should -Not -BeNullOrEmpty
            $found.FullName | Should -Be (Get-Item -LiteralPath $rPath).FullName
        } finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns null when $R is not on disk' {
        $dir = Join-Path $env:TEMP ("FindRMissing_" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $iPath = Join-Path $dir '$IABCDEF.txt'
            Set-Content -LiteralPath $iPath -Value 'i'
            $found = Find-RecycleBinDataItem -IFilePath $iPath
            $found | Should -Be $null
        } finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Get-RecycleBinRoot' {
    It 'resolves -Path to an existing directory' {
        $dir = Join-Path $env:TEMP ("RecycleRoots_" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $roots = Get-RecycleBinRoot -Path $dir
            $roots.Count | Should -Be 1
            $roots[0] | Should -Be (Resolve-Path -LiteralPath $dir).Path
        } finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Get-RecycleBinItem -AnomaliesOnly' {
    It 'returns only items with non-empty Anomalies' {
        $tempRoot = Join-Path $env:TEMP ("Get-RecycleBinItemAnom_" + [guid]::NewGuid().ToString('N'))
        $recycleRoot = Join-Path $tempRoot '$RECYCLE.BIN'
        $sidDir = Join-Path $recycleRoot 'S-1-5-18'
        New-Item -ItemType Directory -Path $sidDir -Force | Out-Null
        try {
            $deleted = [datetime]::SpecifyKind([datetime]'2024-03-01T10:00:00', 'Utc')

            $clean = New-IFileFixture -Directory $sidDir -Name '$ICLEAN.bin' -Version 2 `
                -FileSize 8 -DeletionUtc $deleted -OriginalPath 'C:\clean.bin' -CreateRFile
            $cleanItem = Get-Item -LiteralPath $clean.IPath -Force
            $cleanItem.LastWriteTime = $deleted.ToLocalTime()

            $dirty = New-IFileFixture -Directory $sidDir -Name '$IDIRTY.bin' -Version 2 `
                -FileSize 8 -DeletionUtc $deleted -OriginalPath 'C:\dirty.bin'
            $dirtyItem = Get-Item -LiteralPath $dirty.IPath -Force
            $dirtyItem.LastWriteTime = $deleted.ToLocalTime()

            $all = Get-RecycleBinItem -Path $recycleRoot
            $filtered = Get-RecycleBinItem -Path $recycleRoot -AnomaliesOnly

            $all.Count | Should -Be 2
            $filtered.Count | Should -Be 1
            $filtered[0].RecycleFile | Should -Be $dirty.IPath
            $filtered[0].Anomalies | Should -Match 'RFileMissing'
        } finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

