<#
    Description:
        This script searches all partitions for $RECYCLE.BIN folders, recursively finds files starting with $I,
        and parses their metadata. It extracts FileSize (bytes 8-15), FILETIME (bytes 16-23 as UTC and local time),
        PathLength (bytes 24-27), OriginalPath (bytes 28+ in UTF-16LE), SID from the file path, UserName from the SID,
        and LastModified time from the file's LastWriteTime. Results are output to a CSV file if -CsvPath is provided,
        otherwise displayed as a table in the console.

    Version: 1.0.0
    Author: Recycle Bin Parser Developer
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvPath
)

function ParseRecycleFile {
    param(
        [string]$FilePath,
        [datetime]$LastModified
    )

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)

    if ($bytes.Length -lt 30) {
        return $null
    }

    # Second 8 bytes (indices 8–15): FileSize
    $secondEightBytes = $bytes[8..15]
    $fileSize = [BitConverter]::ToInt64($secondEightBytes, 0)

    # Third 8 bytes (indices 16–23): FILETIME
    $thirdEightBytes = $bytes[16..23]
    $fileTimeValue = [BitConverter]::ToInt64($thirdEightBytes, 0)
    try {
        $utcTime = [DateTime]::FromFileTimeUtc($fileTimeValue)
        $localTime = [DateTime]::FromFileTime($fileTimeValue)
    } catch {
        return $null
    }

    # Next 4 bytes (indices 24–27): PathLength
    $nextFourBytes = $bytes[24..27]
    $pathLength = [BitConverter]::ToInt32($nextFourBytes, 0)

    # File path (index 28 until 00 00, UTF-16LE)
    $pathBytes = @()
    $i = 28
    while ($i -lt ($bytes.Length - 1) -and -not ($bytes[$i] -eq 0x00 -and $bytes[$i + 1] -eq 0x00)) {
        $pathBytes += $bytes[$i]
        $pathBytes += $bytes[$i + 1]
        $i += 2
    }
    if ($i -ge $bytes.Length - 1 -or -not ($bytes[$i] -eq 0x00 -and $bytes[$i + 1] -eq 0x00)) {
        return $null
    }

    $filePathString = [System.Text.Encoding]::Unicode.GetString($pathBytes)

    # Extract SID from FilePath (e.g., C:\$Recycle.Bin\<SID>\$I...)
    $sid = ""
    $userName = ""
    $pathComponents = $FilePath.Split('\')
    if ($pathComponents.Length -ge 3 -and $pathComponents[1] -eq '$Recycle.Bin') {
        $sid = $pathComponents[2]
        try {
            $sidObj = New-Object System.Security.Principal.SecurityIdentifier($sid)
            $userName = $sidObj.Translate([System.Security.Principal.NTAccount]).Value
        } catch {
            $userName = "Unknown (SID: $sid)"
        }
    } else {
        $sid = "Not found"
        $userName = "Unknown"
    }

    [PSCustomObject]@{
        RecycleFile = $FilePath
        FileSize = $fileSize
        UTCTime = $utcTime
        LocalTime = $localTime
        RecycleFileModification = $LastModified
        PathLength = $pathLength
        OriginalPath = $filePathString
        SID = $sid
        UserName = $userName
    }
}

$results = @()

$drives = Get-PSDrive -PSProvider FileSystem

foreach ($drive in $drives) {
    $recycleBin = Join-Path $drive.Root '$RECYCLE.BIN'
    if (Test-Path $recycleBin) {
        $files = Get-ChildItem -Path $recycleBin -Recurse -Filter '$I*' -Force -File -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $parsed = ParseRecycleFile -FilePath $file.FullName -LastModified $file.LastWriteTime
            if ($parsed) {
                $results += $parsed
            }
        }
    }
}

if ($CsvPath) {
    $results | Export-Csv -Path $CsvPath -NoTypeInformation
} else {
    $results | Format-Table -AutoSize
}
