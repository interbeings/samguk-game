param([string]$out)
# Assemble every sprite set into one SETS JSON and inject it into game_src2.html
$s = $PSScriptRoot
function B64($p) { 'data:image/png;base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) }
$parts = @()
# Guan Yu: hand-sliced atlas with named frames
$guanF = [IO.File]::ReadAllText("$s\guan_atlas.json") -replace '"jumpA":\[(\d+),(\d+),(\d+),(\d+),\d+', '"jumpA":[$1,$2,$3,$4,52' -replace '"jumpB":\[(\d+),(\d+),(\d+),(\d+),\d+', '"jumpB":[$1,$2,$3,$4,50'
$parts += '"guan":{"src":"' + (B64 "$s\guan_atlas.png") + '","h":160,"face":1,"f":' + $guanF + '}'
$sets = @(
  @{k='zhangfei'; face=1}, @{k='zhaoyun'; face=1}, @{k='huangzhong'; face=1}, @{k='weiyan'; face=1}, @{k='horse'; face=1},
  @{k='foe'; face=1}, @{k='boss1'; face=1}, @{k='boss2'; face=1}, @{k='boss3'; face=1},
  @{k='boss4'; face=1}, @{k='boss5'; face=1}, @{k='boss6'; face=1}
)
foreach ($e in $sets) {
  $k = $e.k
  if (-not (Test-Path "$s\$($k)_atlas.png")) { Write-Warning "missing $k"; continue }
  $j = [IO.File]::ReadAllText("$s\$k.json") | ConvertFrom-Json
  $fr = [IO.File]::ReadAllText("$s\$k.json")
  $fJson = $fr.Substring($fr.IndexOf('"f":') + 4); $fJson = $fJson.Substring(0, $fJson.Length - 1)
  $parts += '"' + $k + '":{"src":"' + (B64 "$s\$($k)_atlas.png") + '","h":' + $j.h + ',"face":' + $e.face + ',"f":' + $fJson + '}'
}
$json = '{' + ($parts -join ',') + '}'
# backgrounds: bg_<theme>.jpg plus ground line in bg_meta.json ({"field":400,...})
$bgParts = @()
if (Test-Path "$s\bg_meta.json") {
  $meta = Get-Content "$s\bg_meta.json" -Raw | ConvertFrom-Json
  foreach ($p in $meta.PSObject.Properties) {
    $f = "$s\bg_$($p.Name).jpg"
    if (Test-Path $f) { $bgParts += '"' + $p.Name + '":{"src":"data:image/jpeg;base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($f)) + '","gy":' + $p.Value + '}' }
  }
}
$bgJson = '{' + ($bgParts -join ',') + '}'
$html = [IO.File]::ReadAllText("$s\game_src2.html", [Text.Encoding]::UTF8).Replace('__SETS__', $json).Replace('__BGS__', $bgJson)
[IO.File]::WriteAllText($out, $html, (New-Object Text.UTF8Encoding $false))
(Get-Item $out).Length
