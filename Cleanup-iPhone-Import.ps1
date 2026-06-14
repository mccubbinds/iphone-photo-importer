<#
  Cleanup-iPhone-Import.ps1
  Run AFTER the import finishes. Operates only on:
      D:\Pictures\Saved Pictures\iPhone-Import
  For each base filename (e.g. IMG_1234):
    1. QUALITY dupes: if both an original (HEIC/HEIF/DNG) and a converted
       copy (JPG/JPEG/PNG) exist, keep the original, delete the converted.
    2. LIVE PHOTOS: if a still image exists, delete the matching .MOV/.MP4
       motion clip (standalone videos with no matching photo are kept).
  Logs every deletion to D:\Pictures\iphone-cleanup-log.txt
  Nothing is touched outside iPhone-Import.
#>

$dir = 'D:\Pictures\Saved Pictures\iPhone-Import'
$log = 'D:\Pictures\iphone-cleanup-log.txt'
Set-Content -LiteralPath $log -Value ("CLEANUP {0}" -f (Get-Date))
function Log($m) { Add-Content -LiteralPath $log -Value $m }

# lower number = higher quality / preferred to keep
$rank = @{ '.heic'=1; '.heif'=1; '.dng'=1; '.jpeg'=3; '.jpg'=3; '.png'=4 }
$imgExt = $rank.Keys
$vidExt = @('.mov','.mp4','.m4v')

$files = Get-ChildItem -LiteralPath $dir -File
$groups = $files | Group-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }

$del = 0; $freed = 0L
foreach ($g in $groups) {
    $imgs = @($g.Group | Where-Object { $imgExt -contains $_.Extension.ToLower() })
    $vids = @($g.Group | Where-Object { $vidExt -contains $_.Extension.ToLower() })

    # 1. keep best-quality image, delete other same-base images
    if ($imgs.Count -gt 1) {
        $keep = $imgs | Sort-Object @{ E = { $rank[$_.Extension.ToLower()] } }, Name | Select-Object -First 1
        foreach ($im in $imgs) {
            if ($im.FullName -ne $keep.FullName) {
                Log ("QUALITY-DUP  delete {0}  (kept {1})" -f $im.Name, $keep.Name)
                $freed += $im.Length; Remove-Item -LiteralPath $im.FullName -Force; $del++
            }
        }
        $imgs = @($keep)
    }

    # 2. live-photo motion clip: a still exists -> delete the video(s)
    if ($imgs.Count -ge 1 -and $vids.Count -ge 1) {
        foreach ($v in $vids) {
            Log ("LIVE-PHOTO   delete {0}" -f $v.Name)
            $freed += $v.Length; Remove-Item -LiteralPath $v.FullName -Force; $del++
        }
    }
}
$mb = [math]::Round($freed / 1MB, 1)
Log ("DONE deleted {0} files, freed {1} MB" -f $del, $mb)
Write-Host ("Cleanup done: deleted {0} files, freed {1} MB. Log: {2}" -f $del, $mb, $log)
