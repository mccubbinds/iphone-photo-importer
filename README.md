iPhone Photo Importer for Windows

Two PowerShell scripts that copy photos and videos off an iPhone onto a Windows PC over USB — reliably and resumably — and then clean up the import. Built to replace the flaky "import then delete" flow in the Windows Photos app.

Why

When you plug an iPhone into Windows it shows up as an MTP device (a "portable device"), not a normal drive. The built-in Photos app import over MTP has no resume, drops connections on large transfers, and its delete-after-import step frequently fails — so you end up babysitting it and restarting from zero. These scripts talk to the phone through the Windows Shell COM API (the only thing that can reach the MTP namespace) and add the things the Photos app lacks: resume, skip-already-copied, correct file naming, and logging.

Scripts

Import-iPhone-Photos.ps1

Copies every new photo/video from a connected iPhone into a destination folder.


Resumable / safe to re-run — skips files already on disk and picks up where it left off after an error or disconnect.
Fast skip — compares each phone file's base name against what's already on disk locally, instead of doing a slow per-file query to the phone, so the thousands you already have are passed over quickly.
Correct names — reads each file's true name with extension via the System.FileName property (MTP otherwise returns names without extensions), so verification works and live-photo pairs (IMG_1234.HEIC + IMG_1234.MOV) are both kept.
Layout-agnostic — handles both DCIM\100APPLE and date-coded (YYYYMM) folder structures, newest folders first.
Non-destructive — never deletes anything from the iPhone.
Writes progress to a log file.


Cleanup-iPhone-Import.ps1

Run after the import. For each base filename it:


Quality de-dupe — if both an original (HEIC/HEIF/DNG) and a converted copy (JPG/JPEG/PNG) exist, keeps the original and deletes the lower-quality copy. (Useful if you previously transferred with iOS's "Automatic" format conversion on.)
Strips live-photo clips — if a still image exists, deletes the matching .MOV/.MP4 motion clip. Standalone videos with no matching photo are kept.


Logs every deletion.

Requirements


Windows 10/11 with PowerShell (built in)
An iPhone connected by USB, unlocked, with Trust This Computer accepted


Usage


Edit the $dest path at the top of each script to your target folder.
Plug in and unlock the phone, tap Trust.
Run the importer (Win+R, paste, Enter — or right-click → Run with PowerShell):


   powershell -NoProfile -ExecutionPolicy Bypass -File "PATH\TO\Import-iPhone-Photos.ps1"


If it errors or you reboot, just run it again — it resumes.
When the copy is done, run the cleanup:


   powershell -NoProfile -ExecutionPolicy Bypass -File "PATH\TO\Cleanup-iPhone-Import.ps1"

Notes & gotchas


iCloud "Optimize iPhone Storage": if this is on, full-resolution originals live in iCloud and aren't physically on the phone, so MTP can't copy them (they fail or come over empty). Turn on Settings → Photos → Download and Keep Originals, let it finish, then re-run the importer.
Best fidelity: set Settings → Photos → Transfer to Mac or PC → Keep Originals so iOS sends untouched HEIC/HEVC instead of re-encoding to JPG during transfer.
HEIC on Windows: install the free HEIF Image Extensions from the Microsoft Store to preview HEIC files.
Deleting from the phone: these scripts never do it. After you've confirmed the copy, delete on the phone itself, then empty Recently Deleted. (If iCloud Photos is on, that deletes everywhere — verify your copy first.)
MTP is inherently slow; the win here is reliability and resume, not raw speed.


Disclaimer

Provided as-is. The cleanup script deletes files in the destination folder — review what it targets and keep a backup. Use at your own risk.# iphone-photo-importer
Resumable iPhone-to-Windows photo importer + cleanup, in PowerShell. The Windows Photos app import, but it actually finishes.
