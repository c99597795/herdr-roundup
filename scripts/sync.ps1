# Windows counterpart of scripts/sync.sh: installs the layout, its roundup-* mods and its keys into Herdr App.
# Usage:  powershell -ExecutionPolicy Bypass -File scripts\sync.ps1
$ErrorActionPreference = 'Stop'
$src  = Split-Path -Parent $PSScriptRoot
$app  = if ($env:HERDR_APP_HOME) { $env:HERDR_APP_HOME } else { Join-Path $HOME '.config\herdr-app' }
$name = 'Herdr-Roundup'

foreach ($pair in @(@('roundup-tabs','roundup-pane','close.js'), @('roundup-tabs','roundup-pane','menu.js'),
                    @('roundup-preview','roundup-files','open-file.js'), @('roundup-preview','roundup-files','paths.js'))) {
  $a = Get-FileHash (Join-Path $src "mods\$($pair[0])\$($pair[2])"); $b = Get-FileHash (Join-Path $src "mods\$($pair[1])\$($pair[2])")
  if ($a.Hash -ne $b.Hash) { throw "mods/$($pair[0])/$($pair[2]) and mods/$($pair[1])/$($pair[2]) differ" }
}

New-Item -ItemType Directory -Force "$app\layouts","$app\mods","$app\themes" | Out-Null
Copy-Item "$src\layouts\$name.*" "$app\layouts\" -Force

foreach ($d in Get-ChildItem "$src\mods" -Directory -Filter 'roundup-*') {
  $dst = Join-Path "$app\mods" $d.Name
  New-Item -ItemType Directory -Force $dst | Out-Null
  # mirror: copy everything, drop files that left the repo, keep the files the app writes itself
  robocopy $d.FullName $dst /MIR /XF gpui-kit.d.ts jsconfig.json .gitkeep /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed for $($d.Name) ($LASTEXITCODE)" }
}
Get-ChildItem "$src\themes" -Filter *.json -ErrorAction SilentlyContinue | Copy-Item -Destination "$app\themes\" -Force

# keys.json: replace only this layout's section
$keysFile = "$app\keys.json"
$keys = if (Test-Path $keysFile) { Get-Content $keysFile -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
$ours = Get-Content "$src\keys.json" -Raw | ConvertFrom-Json
$keys | Add-Member -NotePropertyName "layout:$name" -NotePropertyValue $ours."layout:$name" -Force
$keys | ConvertTo-Json -Depth 10 | Set-Content $keysFile -Encoding utf8

foreach ($d in Get-ChildItem "$app\mods" -Directory -Filter 'roundup-*') { $global:LASTEXITCODE = 0; herdr-app check $d.FullName; if ($LASTEXITCODE) { throw "check failed: $($d.Name)" } }
$status = herdr-app status | ConvertFrom-Json
if ($status.errors.Count) { $status.errors | Out-String; throw 'Herdr App reports errors' }
Write-Host "Installed. Switch with: herdr-app do layout.switch '{`"name`":`"$name`"}'"

