# Leo's Busy Day - arma index.html a partir de leos-busy-day.html y lo sube a GitHub.
# Uso:  powershell -ExecutionPolicy Bypass -File publicar.ps1 ["mensaje del cambio"]
# Render (Static Site) redespliega solo al recibir el commit.

param([string]$Mensaje = "Actualizar Leo's Busy Day")

$ErrorActionPreference = 'Stop'
$repo   = 'iamaster213-del/leos-busy-day'
$branch = 'main'

$gh = Join-Path $env:LOCALAPPDATA 'Programs\gh\bin\gh.exe'
if (-not (Test-Path $gh)) { $gh = 'gh' }

# index.html = cabecera de documento + el juego (el artifact de claude.ai agrega esa cabecera solo)
$utf8 = New-Object Text.UTF8Encoding($false)
$juego = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'leos-busy-day.html'), $utf8)
$cabecera = "<!doctype html>`n<html lang=`"en`">`n<meta charset=`"utf-8`">`n<meta name=`"viewport`" content=`"width=device-width, initial-scale=1, viewport-fit=cover`">`n"
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'index.html'), $cabecera + $juego, $utf8)

function Get-BlobSha([byte[]]$bytes) {
  $head = [Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)`0")
  $all = New-Object byte[] ($head.Length + $bytes.Length)
  [Array]::Copy($head, $all, $head.Length)
  [Array]::Copy($bytes, 0, $all, $head.Length, $bytes.Length)
  $sha1 = [Security.Cryptography.SHA1]::Create()
  return -join ($sha1.ComputeHash($all) | ForEach-Object { $_.ToString('x2') })
}

$tmp = Join-Path $env:TEMP 'leos-busy-day-subida.json'
$subidos = 0
foreach ($f in @('index.html', 'leos-busy-day.html', 'publicar.ps1')) {
  $bytes = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot $f))
  $local = Get-BlobSha $bytes
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  $remote = & $gh api "repos/$repo/contents/$($f)?ref=$branch" --jq .sha 2>$null
  $ErrorActionPreference = $old
  if ($LASTEXITCODE -ne 0) { $remote = $null }
  if ($remote -eq $local) { Write-Host "  = $f (sin cambios)"; continue }
  $body = @{ message = "$Mensaje ($f)"; branch = $branch; content = [Convert]::ToBase64String($bytes) }
  if ($remote) { $body.sha = $remote }
  [IO.File]::WriteAllText($tmp, ($body | ConvertTo-Json -Compress), $utf8)
  & $gh api -X PUT "repos/$repo/contents/$f" --input $tmp --jq .commit.sha | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "No se pudo subir $f" }
  Write-Host "  ^ $f subido"
  $subidos++
}
Remove-Item $tmp -ErrorAction SilentlyContinue
if ($subidos) { Write-Host "Listo: $subidos archivo(s) en github.com/$repo" } else { Write-Host "No había nada nuevo que subir." }
