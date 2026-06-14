<#
  Import-iPhone-Photos.ps1  (v5)
  Copies new photos/videos from a connected iPhone (MTP) into
      D:\Pictures\Saved Pictures\iPhone-Import
  - Fast skip: compares each phone file's base name (no per-file MTP query)
    against what's already on disk, so the ~thousands already copied are
    passed over quickly. Only genuinely-new files get the slower full-name
    lookup + copy.
  - Newest folders first, so new shots come over first.
  - Keeps live-photo pairs (HEIC + MOV).
  - Safe to re-run / resumes. Never deletes from the iPhone.
  - Progress -> D:\Pictures\iphone-import-log.txt
#>

$ErrorActionPreference = 'Continue'
$dest = 'D:\Pictures\Saved Pictures\iPhone-Import'
$log  = 'D:\Pictures\iphone-import-log.txt'

if (-not (Test-Path -LiteralPath $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
function Log($m) { Add-Content -LiteralPath $log -Value ("{0}  {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) }
Set-Content -LiteralPath $log -Value ("START {0}" -f (Get-Date))

$shell = New-Object -ComObject Shell.Application
$thisPC = $shell.NameSpace(0x11)
$phone = $null
foreach ($i in $thisPC.Items()) { if ($i.Name -match 'iPhone|Apple') { $phone = $i; break } }
if (-not $phone) { Log "ERROR iPhone not found - unlock + Trust, then re-run."; return }

$root = $null
foreach ($s in $phone.GetFolder.Items()) { if ($s.Name -match 'Internal|Storage') { $root = $s; break } }
if (-not $root) { $root = $phone }
Log ("Device: {0} \ {1}" -f $phone.Name, $root.Name)

# Frozen set of base names already on disk (e.g. IMG_5763)
$origBase = @{}
Get-ChildItem -LiteralPath $dest -File -ErrorAction SilentlyContinue | ForEach-Object {
    $origBase[[System.IO.Path]::GetFileNameWithoutExtension($_.Name)] = $true
}
Log ("Already on disk: {0} base names" -f $origBase.Count)

$destNs = $shell.NameSpace($dest)
$copiedFull = @{}
$script:copied = 0; $script:skipped = 0; $script:failed = @()

function Get-RealName($it) {
    $n = $it.ExtendedProperty("System.FileName")
    if ([string]::IsNullOrEmpty($n)) { $n = $it.Name }
    return $n
}

function Walk($folderItem) {
    foreach ($it in $folderItem.GetFolder.Items()) {
        if ($it.IsFolder) { Walk $it; continue }
        $base = [System.IO.Path]::GetFileNameWithoutExtension($it.Name)
        if ($origBase.ContainsKey($base)) { $script:skipped++; continue }   # fast skip, no MTP query
        $name = Get-RealName $it
        if ($copiedFull.ContainsKey($name)) { $script:skipped++; continue }
        $destNs.CopyHere($it, 16)
        $target = Join-Path $dest $name
        $t = 0
        while (-not (Test-Path -LiteralPath $target) -and $t -lt 240) { Start-Sleep -Milliseconds 250; $t++ }
        if (Test-Path -LiteralPath $target) {
            $copiedFull[$name] = $true; $script:copied++
            if ($script:copied % 10 -eq 0) { Log ("PROGRESS copied={0} skipped={1} failed={2}" -f $script:copied,$script:skipped,$script:failed.Count) }
        } else { $script:failed += $name; Log ("SLOW/FAILED {0}" -f $name) }
    }
}

# Newest date-folders first
$folders = @()
foreach ($s in $root.GetFolder.Items()) { $folders += $s }
$folders = $folders | Sort-Object { $_.Name } -Descending

Log ("Scanning {0} folders (newest first)..." -f $folders.Count)
foreach ($f in $folders) {
    if ($f.IsFolder) { Log ("Folder {0}" -f $f.Name); Walk $f }
    elseif (-not $origBase.ContainsKey([System.IO.Path]::GetFileNameWithoutExtension($f.Name))) {
        # stray file directly under root
        $name = Get-RealName $f
        if (-not $copiedFull.ContainsKey($name)) {
            $destNs.CopyHere($f, 16); $copiedFull[$name] = $true; $script:copied++
        }
    }
}
Log ("DONE copied={0} skipped={1} failed={2}" -f $script:copied,$script:skipped,$script:failed.Count)
if ($script:failed.Count) { $script:failed | ForEach-Object { Log ("RETRY-NEEDED {0}" -f $_) } }
Log "Nothing was deleted from the iPhone."
