<#
.SYNOPSIS
    Builds synthetic Windows Recycle Bin $I file bytes for tests.
#>

function New-IFileBytes {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet(1, 2)]
        [int]$Version,

        [Parameter(Mandatory = $true)]
        [int64]$FileSize,

        [Parameter(Mandatory = $true)]
        [datetime]$DeletionUtc,

        [Parameter(Mandatory = $true)]
        [string]$OriginalPath,

        [switch]$OmitPathNul,
        [switch]$Truncate,
        [int]$OverridePathCharCount
    )

    $fileTime = $DeletionUtc.ToFileTimeUtc()
    $pathBytes = [System.Text.Encoding]::Unicode.GetBytes($OriginalPath)

    if ($Version -eq 1) {
        $buffer = New-Object byte[] 544
        [BitConverter]::GetBytes([int64]1).CopyTo($buffer, 0)
        [BitConverter]::GetBytes($FileSize).CopyTo($buffer, 8)
        [BitConverter]::GetBytes($fileTime).CopyTo($buffer, 16)
        $copyLen = [Math]::Min($pathBytes.Length, 518)
        [Array]::Copy($pathBytes, 0, $buffer, 24, $copyLen)
        # Bytes 24+518 default to 0 (NUL terminator + padding)
        if ($OmitPathNul -and $copyLen -ge 2) {
            # Overwrite end of path slot so there is no early NUL — fill with 'A'
            for ($i = 24; $i -lt 544; $i++) {
                $buffer[$i] = 0x41
            }
            [Array]::Copy($pathBytes, 0, $buffer, 24, $copyLen)
        }
        if ($Truncate) {
            return $buffer[0..([Math]::Min(20, $buffer.Length - 1))]
        }
        return $buffer
    }

    $charCountIncludingNul = if ($PSBoundParameters.ContainsKey('OverridePathCharCount')) {
        [uint32]$OverridePathCharCount
    } else {
        [uint32](($pathBytes.Length / 2) + 1)
    }

    $pathRegionLen = [int]($charCountIncludingNul * 2)
    $total = 28 + $pathRegionLen
    $buffer = New-Object byte[] $total
    [BitConverter]::GetBytes([int64]2).CopyTo($buffer, 0)
    [BitConverter]::GetBytes($FileSize).CopyTo($buffer, 8)
    [BitConverter]::GetBytes($fileTime).CopyTo($buffer, 16)
    [BitConverter]::GetBytes($charCountIncludingNul).CopyTo($buffer, 24)

    $copyLen = [Math]::Min($pathBytes.Length, [Math]::Max(0, $pathRegionLen - 2))
    if ($copyLen -gt 0) {
        [Array]::Copy($pathBytes, 0, $buffer, 28, $copyLen)
    }

    if ($OmitPathNul -and $pathRegionLen -ge 2) {
        $buffer[$total - 2] = 0x41
        $buffer[$total - 1] = 0x00
    }

    if ($Truncate) {
        return $buffer[0..([Math]::Min(30, $buffer.Length - 1))]
    }

    return $buffer
}

function New-IFileFixture {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet(1, 2)]
        [int]$Version,

        [Parameter(Mandatory = $true)]
        [int64]$FileSize,

        [Parameter(Mandatory = $true)]
        [datetime]$DeletionUtc,

        [Parameter(Mandatory = $true)]
        [string]$OriginalPath,

        [switch]$CreateRFile,
        [int64]$RFileSize,
        [switch]$OmitPathNul,
        [switch]$Truncate,
        [int]$OverridePathCharCount
    )

    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    }

    $params = @{
        Version      = $Version
        FileSize     = $FileSize
        DeletionUtc  = $DeletionUtc
        OriginalPath = $OriginalPath
    }
    if ($OmitPathNul) { $params.OmitPathNul = $true }
    if ($Truncate) { $params.Truncate = $true }
    if ($PSBoundParameters.ContainsKey('OverridePathCharCount')) {
        $params.OverridePathCharCount = $OverridePathCharCount
    }

    $bytes = New-IFileBytes @params
    $iPath = Join-Path $Directory $Name
    [System.IO.File]::WriteAllBytes($iPath, $bytes)

    $rPath = $null
    if ($CreateRFile) {
        $rName = '$R' + $Name.Substring(2)
        $rPath = Join-Path $Directory $rName
        $size = if ($PSBoundParameters.ContainsKey('RFileSize')) { $RFileSize } else { $FileSize }
        $payload = New-Object byte[] ([Math]::Max(0, $size))
        [System.IO.File]::WriteAllBytes($rPath, $payload)
    }

    [PSCustomObject]@{
        IPath = $iPath
        RPath = $rPath
    }
}
