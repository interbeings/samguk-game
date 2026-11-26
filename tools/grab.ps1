param([string]$dest)
Add-Type -AssemblyName System.Drawing
$dl = "$env:USERPROFILE\Downloads"
$used = "$PSScriptRoot\grabbed.txt"
$seen = @(); if (Test-Path $used) { $seen = Get-Content $used }
for ($i = 0; $i -lt 30; $i++) {
  $f = Get-ChildItem $dl -File | Where-Object { $_.LastWriteTime -gt (Get-Date).AddSeconds(-90) -and $_.Length -gt 100000 -and ($seen -notcontains $_.Name) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($f) {
    try { $img = [System.Drawing.Image]::FromFile($f.FullName); $sz = "$($img.Width)x$($img.Height)"; $img.Dispose()
      Copy-Item $f.FullName $dest -Force; Add-Content $used $f.Name; "saved $dest ($sz) from $($f.Name)"; return } catch {}
  }
  Start-Sleep -Milliseconds 700
}
"no new download found"
