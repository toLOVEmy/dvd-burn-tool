<#
====================================================================
  DVD Burn Tool - Portable Version v3
====================================================================
  Supports BOTH:
    - First burn on a blank disc (no import needed)
    - Append to an existing non-finalized disc (preserve old files)
  
  Use on ANY Windows 7+ host with a DVD burner.
  
  Parameters:
    -Path / -SourceDir  File or folder to burn/append (default: script's own folder)
    -RecorderIdx        Index of recorder to use (default: 0)
    -ShowDrives         List available drives and exit
    
  Examples:
    .\dvd_burn_tool.ps1 -Path "D:\backup"                     # burn/append folder
    .\dvd_burn_tool.ps1 -Path "D:\data\report.pdf"            # burn/append single file
    .\dvd_burn_tool.ps1 -ShowDrives                            # list drives only
====================================================================
#>

param(
    [Alias('SourceDir')]
    [string]$Path = "",
    [int]$RecorderIdx = 0,
    [switch]$ShowDrives
)

$ErrorActionPreference = "Stop"

# Save script root at top level
$ScriptRoot = Split-Path -Parent $PSCommandPath

# ==================================================================
# Helper: get drive letter from recorder
# ==================================================================
function Get-DriveLetter {
    param($Recorder)
    try {
        $vps = $Recorder.VolumePathStrings
        if ($vps -and $vps.Count -gt 0 -and $vps[0]) {
            $letter = $vps[0].TrimEnd('\')
            if ($letter -match '^[A-Za-z]:') { return $letter }
        }
    } catch { }
    try {
        $cdDrives = @(Get-CimInstance Win32_CDROMDrive -ErrorAction SilentlyContinue)
        if ($cdDrives.Count -gt 0) { return $cdDrives[0].Drive.TrimEnd('\') }
    } catch { }
    try {
        $allDrives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=5" -ErrorAction SilentlyContinue
        if ($allDrives -and $allDrives.Count -gt 0) { return $allDrives[0].DeviceID.TrimEnd('\') }
    } catch { }
    return $null
}

# ==================================================================
# Helper: resolve source path
# ==================================================================
function Get-SourceInfo {
    param([string]$RawPath, [string]$DefaultDir)
    if ([string]::IsNullOrEmpty($RawPath)) {
        return @{ SourceDir = $DefaultDir; IsSingleFile = $false; SingleFileName = $null }
    }
    $resolved = Resolve-Path $RawPath -ErrorAction SilentlyContinue
    if (-not $resolved) { Write-Host "[ERROR] Path not found: $RawPath"; exit 1 }
    $fullPath = $resolved.Path
    if (Test-Path $fullPath -PathType Container) {
        return @{ SourceDir = $fullPath; IsSingleFile = $false; SingleFileName = $null }
    } elseif (Test-Path $fullPath -PathType Leaf) {
        $parent = Split-Path -Parent $fullPath
        $name = Split-Path -Leaf $fullPath
        return @{ SourceDir = $parent; IsSingleFile = $true; SingleFileName = $name }
    } else {
        Write-Host "[ERROR] Path is neither file nor folder: $RawPath"; exit 1
    }
}

# ==================================================================
# Helper: collect files to burn
# ==================================================================
function Get-FilesToBurn {
    param($Info)
    if ($Info.IsSingleFile) {
        return @(Get-Item (Join-Path $Info.SourceDir $Info.SingleFileName) -ErrorAction Stop)
    } else {
        return @(Get-ChildItem $Info.SourceDir -File -ErrorAction SilentlyContinue)
    }
}

# ==================================================================
# Helper: stage a single file for AddTree
# ==================================================================
function Stage-SingleFile {
    param($File)
    $tempStaging = Join-Path $env:TEMP "dvd_burn_staging"
    if (-not (Test-Path $tempStaging)) { New-Item -ItemType Directory -Path $tempStaging -Force | Out-Null }
    else { Remove-Item "$tempStaging\*" -Force -ErrorAction SilentlyContinue }
    Copy-Item $File.FullName $tempStaging -Force
    return $tempStaging
}

# ==================================================================
# List available drives
# ==================================================================
Write-Host "=== Scanning optical drives ==="
try { $dm = New-Object -ComObject IMAPI2.MsftDiscMaster2 }
catch { Write-Host "[FATAL] IMAPI2 not supported (need Windows 7+)."; exit 1 }

$driveCount = $dm.Count
if ($driveCount -eq 0) { Write-Host "[ERROR] No optical drive found."; exit 1 }

for ($i = 0; $i -lt $driveCount; $i++) {
    $recTmp = New-Object -ComObject IMAPI2.MsftDiscRecorder2
    try {
        $recTmp.InitializeDiscRecorder($dm[$i])
        $dl = Get-DriveLetter $recTmp
        $dlStr = if ($dl) { "Drive: $dl" } else { "(unknown)" }
        Write-Host "   [$i] $($recTmp.ProductId)  ($dlStr)"
    } catch { Write-Host "   [$i] (unavailable)" }
}

if ($ShowDrives) { Write-Host "`nUse -RecorderIdx N to select the correct drive."; exit 0 }
if ($RecorderIdx -ge $driveCount) { Write-Host "[ERROR] RecorderIdx $RecorderIdx out of range (0..$($driveCount-1))."; exit 1 }

# ==================================================================
# Step 1: Initialize recorder
# ==================================================================
Write-Host ""
Write-Host "=== 1. Select recorder [$RecorderIdx] ==="
$rec = New-Object -ComObject IMAPI2.MsftDiscRecorder2
$rec.InitializeDiscRecorder($dm[$RecorderIdx])
Write-Host "   $($rec.ProductId)"
$driveLetter = Get-DriveLetter $rec
if ($driveLetter) { Write-Host "   Drive: $driveLetter" }
else { Write-Host "   [WARN] Could not detect drive letter." }

# ==================================================================
# Step 2: Check disc status (bitmask)
# ==================================================================
Write-Host ""
Write-Host "=== 2. Check disc status ==="
$df = New-Object -ComObject IMAPI2.MsftDiscFormat2Data
$df.Recorder = $rec
$df.ClientName = "CodeBurnTool"

$status = $df.CurrentMediaStatus
$isBlank = ($status -band 0x1) -ne 0
$isAppendable = ($status -band 0x2) -ne 0
$isOpen = ($status -band 0x4) -ne 0
$isClosed = ($status -band 0x8) -ne 0

$freeMB = [math]::Round($df.FreeSectorsOnMedia * 2048 / 1MB, 2)
Write-Host "   Status: $status  (Blank=$isBlank, Open=$isOpen, Closed=$isClosed)"
Write-Host "   Free: $freeMB MB"
Write-Host "   Disc type: $(if($isBlank){'BLANK (first burn)'}elseif($isClosed){'CLOSED/FINALIZED'}else{'EXISTING (append)'})"

if ($isClosed) {
    Write-Host "[ERROR] Disc is finalized/closed. Cannot write more data."
    exit 1
}

# ==================================================================
# Step 3: Resolve source files
# ==================================================================
Write-Host ""
Write-Host "=== 3. Source path ==="
$sourceInfo = Get-SourceInfo $Path $ScriptRoot
Write-Host "   $($sourceInfo.SourceDir)"
if ($sourceInfo.IsSingleFile) { Write-Host "   (single file mode: $($sourceInfo.SingleFileName))" }

$pendingFiles = Get-FilesToBurn $sourceInfo
if ($pendingFiles.Count -eq 0) { Write-Host "[INFO] No files found."; exit 0 }

Write-Host "   $($pendingFiles.Count) file(s) to write:"
foreach ($f in $pendingFiles) {
    $sizeKB = [math]::Round($f.Length / 1KB, 1)
    Write-Host "       $($f.Name)  ($sizeKB KB)"
}

# ==================================================================
# Step 4: Create / Import filesystem
# ==================================================================
Write-Host ""
$fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
$fsi.FileSystemsToCreate = 7    # UDF + Joliet

if ($isBlank) {
    # === BLANK DISC: fresh filesystem, no import ===
    Write-Host "=== 4. Blank disc - creating new filesystem ==="
    $fsi.FreeMediaBlocks = $df.FreeSectorsOnMedia
    Write-Host "   New filesystem created (blank disc)"
} else {
    # === EXISTING DISC: import multisession ===
    Write-Host "=== 4. Existing disc - import filesystem ==="
    try {
        $msInterfaces = $df.MultisessionInterfaces
        $fsi.MultisessionInterfaces = @($msInterfaces[0])
        $fsi.FreeMediaBlocks = $df.FreeSectorsOnMedia
        $fsi.ImportFileSystem()
        Write-Host "   OK - existing files preserved"
    } catch {
        Write-Host "   [WARN] Import failed, trying fresh filesystem..."
        Write-Host "   ($($_.Exception.Message))"
        $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
        $fsi.FileSystemsToCreate = 7
        $fsi.FreeMediaBlocks = $df.FreeSectorsOnMedia
        # Try with empty multisession interface as fallback
        try {
            $msInterfaces = $df.MultisessionInterfaces
            if ($msInterfaces -and $msInterfaces.Count -gt 0 -and $msInterfaces[0]) {
                $fsi.MultisessionInterfaces = @($msInterfaces[0])
                $fsi.ImportFileSystem()
                Write-Host "   OK - fallback import succeeded"
            }
        } catch {
            Write-Host "   Fresh filesystem used (existing files may be lost)"
        }
    }
}

# ==================================================================
# Step 5: Add files to disc
# ==================================================================
Write-Host ""
Write-Host "=== 5. Write to disc (not finalized) ==="
$rootDir = $fsi.Root

if ($sourceInfo.IsSingleFile) {
    $stagingDir = Stage-SingleFile $pendingFiles[0]
    Write-Host "   Adding: $($pendingFiles[0].Name)"
    $rootDir.AddTree($stagingDir, $false)
} else {
    Write-Host "   Adding folder: $($sourceInfo.SourceDir)"
    $rootDir.AddTree($sourceInfo.SourceDir, $false)
}

$df.ForceMediaToBeClosed = $false

Write-Host "   Burning to disc, please wait..."
$result = $fsi.CreateResultImage()
$stream = $result.ImageStream
$df.Write($stream)
Write-Host "   Done!"

# ==================================================================
# Step 6: Verify
# ==================================================================
if ($driveLetter) {
    Write-Host ""
    Write-Host "=== 6. Verify ==="
    Start-Sleep 10
    try {
        $files = Get-ChildItem "${driveLetter}\" -ErrorAction Stop
        Write-Host "   $driveLetter has $($files.Count) files:"
        $files | Select Name, Length | Format-Table -AutoSize
    } catch {
        Start-Sleep 5
        try {
            $files = Get-ChildItem "${driveLetter}\" -ErrorAction Stop
            $files | Select Name, Length | Format-Table -AutoSize
        } catch {
            Write-Host "   [WARN] Drive not ready yet after burn."
        }
    }
} else {
    Write-Host ""
    Write-Host "=== 6. Verify (skipped - drive letter unknown) ==="
    Write-Host "   Check your DVD drive manually."
}

# ==================================================================
# Step 7: Final status
# ==================================================================
Write-Host ""
Write-Host "=== 7. Disc status after burn ==="
$df2 = New-Object -ComObject IMAPI2.MsftDiscFormat2Data
$df2.Recorder = $rec
$s2 = $df2.CurrentMediaStatus
Write-Host "   Status: $s2  ($(if($s2 -band 0x4){'Open - can append again'}else{'Unknown'}))"
Write-Host ""
if ($isBlank) {
    Write-Host "[SUCCESS] First burn complete! Disc is open for future appends."
} else {
    Write-Host "[SUCCESS] Files appended successfully! Disc still open."
}
Write-Host "[TIP]    Run again with new files to append more."
