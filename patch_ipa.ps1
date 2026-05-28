# BSD Brawl Stars iOS Patcher
# Applies BSD mod CSV patches from APK to IPA
# Usage: Place APK and IPA in the same folder, then run this script

param(
    [string]$ApkPath = "",
    [string]$IpaPath = "",
    [string]$OutputPath = ""
)

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $ApkPath) {
    $ApkPath = Get-ChildItem $scriptDir -Filter "*.apk" | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $IpaPath) {
    $IpaPath = Get-ChildItem $scriptDir -Filter "*.ipa" | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $OutputPath) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($IpaPath)
    $OutputPath = Join-Path $scriptDir "${baseName}_MODDED.ipa"
}

if (-not $ApkPath -or -not (Test-Path $ApkPath)) {
    Write-Error "APK not found. Place the BSD mod APK in the same folder or use -ApkPath"
    exit 1
}
if (-not $IpaPath -or -not (Test-Path $IpaPath)) {
    Write-Error "IPA not found. Place the Brawl Stars IPA in the same folder or use -IpaPath"
    exit 1
}

$tempDir = Join-Path $env:TEMP "bsd_ios_patch_$(Get-Random)"

Write-Host "=================================="
Write-Host "  BSD Brawl Stars iOS Patcher"
Write-Host "=================================="
Write-Host "APK : $ApkPath"
Write-Host "IPA : $IpaPath"
Write-Host "OUT : $OutputPath"
Write-Host ""

$patchMap = @{
    "assets/bsd/mods/BSDCsvPatches/csv_client/effects.csv"        = "Payload/laser.app/res/csv_client/effects.csv"
    "assets/bsd/mods/BSDCsvPatches/csv_client/music.csv"          = "Payload/laser.app/res/csv_client/music.csv"
    "assets/bsd/mods/BSDCsvPatches/csv_logic/location_themes.csv" = "Payload/laser.app/res/csv_logic/location_themes.csv"
    "assets/bsd/mods/BSDCsvPatches/csv_logic/themes.csv"          = "Payload/laser.app/res/csv_logic/themes.csv"
}

Write-Host "[1/3] Extracting patch files from APK..."
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$apkZip = [System.IO.Compression.ZipFile]::OpenRead($ApkPath)
$extracted = 0

foreach ($apkEntry in $patchMap.Keys) {
    $entry = $apkZip.Entries | Where-Object { $_.FullName -eq $apkEntry }
    if ($entry) {
        $fileName = ($apkEntry -split "/")[-1]
        $prefix = if ($apkEntry -like "*/csv_client/*") { "csv_client_" } else { "csv_logic_" }
        $outFile = Join-Path $tempDir "$prefix$fileName"
        $stream = $entry.Open()
        $fs = [System.IO.File]::Create($outFile)
        $stream.CopyTo($fs)
        $fs.Close(); $stream.Close()
        Write-Host "  Extracted: $($fileName) ($([math]::Round($entry.Length/1KB,1)) KB)"
        $extracted++
    } else {
        Write-Warning "  Not found in APK: $apkEntry"
    }
}
$apkZip.Dispose()

if ($extracted -eq 0) {
    Write-Error "No patch files found. Make sure this is a BSD mod APK."
    Remove-Item -Recurse -Force $tempDir
    exit 1
}

Write-Host ""
Write-Host "[2/3] Copying IPA (may take a minute)..."
Copy-Item $IpaPath $OutputPath -Force
Write-Host "  Done: $([math]::Round((Get-Item $OutputPath).Length/1MB,1)) MB"

Write-Host ""
Write-Host "[3/3] Applying patches..."
$ipaZip = [System.IO.Compression.ZipFile]::Open($OutputPath, [System.IO.Compression.ZipArchiveMode]::Update)
$patched = 0

foreach ($apkEntry in $patchMap.Keys) {
    $ipaEntry = $patchMap[$apkEntry]
    $fileName = ($apkEntry -split "/")[-1]
    $prefix = if ($apkEntry -like "*/csv_client/*") { "csv_client_" } else { "csv_logic_" }
    $tempFile = Join-Path $tempDir "$prefix$fileName"
    if (-not (Test-Path $tempFile)) { continue }

    $existing = $ipaZip.Entries | Where-Object { $_.FullName -eq $ipaEntry }
    if ($existing) { $existing.Delete() }

    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $ipaZip, $tempFile, $ipaEntry,
        [System.IO.Compression.CompressionLevel]::Optimal
    ) | Out-Null
    Write-Host "  Patched: $ipaEntry"
    $patched++
}

$ipaZip.Dispose()
Remove-Item -Recurse -Force $tempDir

Write-Host ""
Write-Host "=================================="
Write-Host "  DONE! Patched $patched files."
Write-Host "=================================="
Write-Host "Output: $OutputPath"
Write-Host "Size  : $([math]::Round((Get-Item $OutputPath).Length/1MB,1)) MB"
Write-Host ""
Write-Host "Install via Sideloadly or AltStore."
