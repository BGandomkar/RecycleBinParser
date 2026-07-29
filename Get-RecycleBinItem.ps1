<#
.SYNOPSIS
    Gets Windows Recycle Bin item metadata from $I files across drives or a custom path.

.DESCRIPTION
    Searches $RECYCLE.BIN folders for $I* metadata files, parses Vista+ format
    versions 1 and 2, pairs each entry with its matching $R content file, resolves
    SID to username when possible, and reports integrity anomalies.

    Non-administrators can still parse their own Recycle Bin SID folder; other
    users' folders may be inaccessible without elevation.

.PARAMETER CsvPath
    Optional path to write results as CSV. If omitted, results are written with Format-List.

.PARAMETER Drive
    Optional drive letter (e.g. C or C:) to scan only that volume's $RECYCLE.BIN.
    Mutually exclusive with -Path.

.PARAMETER Path
    Optional absolute path to a $RECYCLE.BIN tree (live folder or offline copy).
    Mutually exclusive with -Drive.

.PARAMETER AnomaliesOnly
    Return only items whose Anomalies field is non-empty.

.EXAMPLE
    .\Get-RecycleBinItem.ps1

    Scan all filesystem drives and list results in the console.

.EXAMPLE
    .\Get-RecycleBinItem.ps1 -Drive C -CsvPath C:\temp\recycle.csv -Verbose

    Scan only C:\$RECYCLE.BIN and export CSV with verbose parse messages.

.EXAMPLE
    .\Get-RecycleBinItem.ps1 -Path D:\evidence\$RECYCLE.BIN

    Parse an offline or mounted Recycle Bin copy.

.EXAMPLE
    .\Get-RecycleBinItem.ps1 -AnomaliesOnly

    Show only Recycle Bin items that have one or more anomaly flags.

.NOTES
    Version: 1.3.0
    License: MPL-2.0
    $I format: version 1 (Vista-8.1), version 2 (Windows 10+).
#>

[CmdletBinding(DefaultParameterSetName = 'AllDrives')]
param(
    [Parameter(Mandatory = $false)]
    [string]$CsvPath,

    [Parameter(Mandatory = $false, ParameterSetName = 'Drive')]
    [ValidateNotNullOrEmpty()]
    [string]$Drive,

    [Parameter(Mandatory = $false, ParameterSetName = 'Path')]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [switch]$AnomaliesOnly
)

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-RecycleBinDataPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$IFilePath
    )

    $directory = Split-Path -Parent $IFilePath
    $leaf = Split-Path -Leaf $IFilePath
    if ($leaf.Length -lt 2 -or -not $leaf.StartsWith('$I', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }

    $rLeaf = '$R' + $leaf.Substring(2)
    return Join-Path $directory $rLeaf
}

function Resolve-RecycleBinSid {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $sid = 'Not found'
    $userName = 'Unknown'
    $unknownSid = $false

    $pathComponents = $FilePath.Split([char[]]@('\', '/'), [System.StringSplitOptions]::RemoveEmptyEntries)
    $recycleIndex = -1
    for ($i = 0; $i -lt $pathComponents.Length; $i++) {
        if ($pathComponents[$i] -ieq '$RECYCLE.BIN') {
            $recycleIndex = $i
            break
        }
    }

    if ($recycleIndex -ge 0 -and ($recycleIndex + 1) -lt $pathComponents.Length) {
        $sid = $pathComponents[$recycleIndex + 1]
        try {
            $sidObj = New-Object System.Security.Principal.SecurityIdentifier($sid)
            try {
                $userName = $sidObj.Translate([System.Security.Principal.NTAccount]).Value
            } catch {
                $userName = "Unknown (SID: $sid)"
                $unknownSid = $true
            }
        } catch {
            $userName = "Unknown (SID: $sid)"
            $unknownSid = $true
        }
    }

    [PSCustomObject]@{
        SID        = $sid
        UserName   = $userName
        UnknownSid = $unknownSid
    }
}

function ConvertFrom-RecycleBinIFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [datetime]$LastModified
    )

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)

    if ($bytes.Length -lt 24) {
        Write-Verbose "Skipping short file ($($bytes.Length) bytes): $FilePath"
        return $null
    }

    $formatVersion = [BitConverter]::ToInt64($bytes, 0)
    if ($formatVersion -ne 1 -and $formatVersion -ne 2) {
        Write-Verbose "Skipping unknown `$I version $formatVersion : $FilePath"
        return $null
    }

    $fileSize = [BitConverter]::ToInt64($bytes, 8)
    $fileTimeValue = [BitConverter]::ToInt64($bytes, 16)

    try {
        $utcTime = [DateTime]::FromFileTimeUtc($fileTimeValue)
        $localTime = [DateTime]::FromFileTime($fileTimeValue)
    } catch {
        Write-Verbose "Skipping invalid FILETIME in: $FilePath"
        return $null
    }

    $pathLength = 0
    $filePathString = $null

    if ($formatVersion -eq 1) {
        # Fixed path slot at offset 24 (520 bytes / 260 UTF-16 code units), NUL-padded.
        if ($bytes.Length -lt 28) {
            Write-Verbose "Skipping truncated v1 `$I file: $FilePath"
            return $null
        }

        $pathStart = 24
        $pathEndExclusive = [Math]::Min($bytes.Length, 544)
        if (($pathEndExclusive - $pathStart) -lt 2) {
            Write-Verbose "Skipping v1 `$I with empty path region: $FilePath"
            return $null
        }

        $pathByteCount = $pathEndExclusive - $pathStart
        if (($pathByteCount % 2) -ne 0) {
            $pathByteCount--
        }

        $terminatorIndex = -1
        for ($i = $pathStart; $i -lt ($pathStart + $pathByteCount - 1); $i += 2) {
            if ($bytes[$i] -eq 0 -and $bytes[$i + 1] -eq 0) {
                $terminatorIndex = $i
                break
            }
        }

        if ($terminatorIndex -lt 0) {
            Write-Verbose "Skipping v1 `$I without NUL-terminated path: $FilePath"
            return $null
        }

        $rawPathLen = $terminatorIndex - $pathStart
        if ($rawPathLen -gt 0) {
            $filePathString = [System.Text.Encoding]::Unicode.GetString($bytes, $pathStart, $rawPathLen)
        } else {
            $filePathString = ''
        }
        $pathLength = [Math]::Floor($rawPathLen / 2)
    } else {
        # Version 2: UInt32 character count (including NUL) at offset 24; path at 28.
        if ($bytes.Length -lt 28) {
            Write-Verbose "Skipping truncated v2 `$I file: $FilePath"
            return $null
        }

        $charCountIncludingNul = [BitConverter]::ToUInt32($bytes, 24)
        if ($charCountIncludingNul -lt 1) {
            Write-Verbose "Skipping v2 `$I with invalid path length: $FilePath"
            return $null
        }

        $pathByteLength = [int]($charCountIncludingNul * 2)
        $requiredLength = 28 + $pathByteLength
        if ($bytes.Length -lt $requiredLength) {
            Write-Verbose "Skipping v2 `$I path overflow (need $requiredLength, have $($bytes.Length)): $FilePath"
            return $null
        }

        $pathCharsWithoutNul = [int]($charCountIncludingNul - 1)
        $pathLength = $pathCharsWithoutNul
        if ($pathCharsWithoutNul -gt 0) {
            $filePathString = [System.Text.Encoding]::Unicode.GetString($bytes, 28, $pathCharsWithoutNul * 2)
        } else {
            $filePathString = ''
        }

        # Validate trailing NUL
        $nulOffset = 28 + ($pathCharsWithoutNul * 2)
        if ($bytes[$nulOffset] -ne 0 -or $bytes[$nulOffset + 1] -ne 0) {
            Write-Verbose "Skipping v2 `$I without expected path NUL terminator: $FilePath"
            return $null
        }
    }

    $sidInfo = Resolve-RecycleBinSid -FilePath $FilePath

    $rPath = Resolve-RecycleBinDataPath -IFilePath $FilePath
    $rExists = $false
    $rSize = $null
    if ($rPath -and (Test-Path -LiteralPath $rPath -PathType Leaf)) {
        $rExists = $true
        $rSize = (Get-Item -LiteralPath $rPath -Force).Length
    }

    $anomalies = New-Object System.Collections.Generic.List[string]

    if ($LastModified.ToString('yyyy-MM-dd HH:mm:ss') -ne $localTime.ToString('yyyy-MM-dd HH:mm:ss')) {
        [void]$anomalies.Add('ModificationTimeMismatch')
    }
    if (-not $rExists) {
        [void]$anomalies.Add('RFileMissing')
    } elseif ($null -ne $rSize -and $rSize -ne $fileSize) {
        [void]$anomalies.Add('SizeMismatch')
    }
    if ($formatVersion -eq 2 -and $pathLength -ge 0) {
        $pathStart = 28
        $earlyNul = $false
        for ($i = $pathStart; $i -lt ($pathStart + ($pathLength * 2) - 1); $i += 2) {
            if ($bytes[$i] -eq 0 -and $bytes[$i + 1] -eq 0) {
                $earlyNul = $true
                break
            }
        }
        if ($earlyNul) {
            [void]$anomalies.Add('PathLengthMismatch')
        }
    }
    if ($sidInfo.UnknownSid) {
        [void]$anomalies.Add('UnknownSid')
    }

    [PSCustomObject]@{
        RecycleFile             = $FilePath
        FormatVersion           = $formatVersion
        FileSize                = $fileSize
        DeletionUTCTime         = $utcTime
        DeletionLocalTime       = $localTime
        RecycleFileModification = $LastModified
        PathLength              = $pathLength
        OriginalPath            = $filePathString
        RecycleDataFile         = if ($rPath) { $rPath } else { '' }
        RecycleDataExists       = $rExists
        RecycleDataSize         = $rSize
        SID                     = $sidInfo.SID
        UserName                = $sidInfo.UserName
        Anomalies               = ($anomalies -join ', ')
    }
}

function Get-RecycleBinRoot {
    param(
        [string]$Drive,
        [string]$Path
    )

    $roots = New-Object System.Collections.Generic.List[string]

    if ($Path) {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Path not found: $Path"
        }
        [void]$roots.Add((Resolve-Path -LiteralPath $Path).Path)
        return , $roots.ToArray()
    }

    if ($Drive) {
        $letter = $Drive.TrimEnd(':', '\', '/')
        if ($letter.Length -ne 1 -or $letter -notmatch '^[A-Za-z]$') {
            throw "Invalid Drive value '$Drive'. Use a single letter such as C or C:."
        }
        $recycleBin = Join-Path "${letter}:" '$RECYCLE.BIN'
        if (Test-Path -LiteralPath $recycleBin) {
            [void]$roots.Add($recycleBin)
        } else {
            Write-Verbose "No `$RECYCLE.BIN found on drive ${letter}:"
        }
        return , $roots.ToArray()
    }

    foreach ($fsDrive in Get-PSDrive -PSProvider FileSystem) {
        if (-not $fsDrive.Root) {
            continue
        }
        $recycleBin = Join-Path $fsDrive.Root '$RECYCLE.BIN'
        if (Test-Path -LiteralPath $recycleBin) {
            [void]$roots.Add($recycleBin)
        }
    }

    return , $roots.ToArray()
}

function Get-RecycleBinItem {
    param(
        [string]$Drive,
        [string]$Path,
        [switch]$AnomaliesOnly
    )

    if (-not (Test-IsAdministrator)) {
        Write-Warning "Not running elevated. Other users' Recycle Bin folders may be inaccessible; your own SID folder can still be parsed."
    }

    $results = New-Object System.Collections.Generic.List[object]
    $roots = Get-RecycleBinRoot -Drive $Drive -Path $Path

    foreach ($root in $roots) {
        Write-Verbose "Scanning: $root"
        try {
            $files = Get-ChildItem -LiteralPath $root -Recurse -Filter '$I*' -Force -File -ErrorAction SilentlyContinue
        } catch {
            Write-Verbose "Failed to enumerate $root : $_"
            continue
        }

        foreach ($file in $files) {
            try {
                $parsed = ConvertFrom-RecycleBinIFile -FilePath $file.FullName -LastModified $file.LastWriteTime
                if ($parsed) {
                    if ($AnomaliesOnly -and [string]::IsNullOrWhiteSpace($parsed.Anomalies)) {
                        continue
                    }
                    [void]$results.Add($parsed)
                }
            } catch {
                Write-Verbose "Failed to parse $($file.FullName): $_"
            }
        }
    }

    return , $results
}

# Run when executed; skip when dot-sourced (e.g. Pester).
if ($MyInvocation.InvocationName -ne '.') {
    $results = Get-RecycleBinItem -Drive $Drive -Path $Path -AnomaliesOnly:$AnomaliesOnly
    if ($CsvPath) {
        $results | Export-Csv -Path $CsvPath -NoTypeInformation
        Write-Verbose "Wrote $($results.Count) row(s) to $CsvPath"
    } else {
        $results | Format-List
    }
}
