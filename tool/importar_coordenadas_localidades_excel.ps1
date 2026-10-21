<#
.SYNOPSIS
  Importa las coordenadas (lat/lng) de las localidades del tabulador de fletes.

.DESCRIPTION
  - Lee una hoja de Excel con columnas LOCALIDAD, LAT y LNG (encabezados en la
    primera fila; el orden no importa).
  - Actualiza `fletes_tabulador.lat` y `fletes_tabulador.lng` de cada localidad
    existente (coincidencia por nombre, sin distinguir mayusculas/minusculas).
  - Las localidades que no existan en el tabulador se reportan y no se crean.
  - Idempotente: se puede volver a ejecutar para corregir coordenadas.

.PARAMETER Archivo
  Ruta del Excel. Por defecto: .\Coordenadas_localidades.xlsx

.PARAMETER Hoja
  Nombre de la hoja. Por defecto: Localidades

.PARAMETER EnvFile / TokenFile
  env.json (SUPABASE_URL + anon key) y archivo con el PAT. Como en los demas
  scripts de importacion.

.PARAMETER AdminEmail / AdminPassword
  Credenciales del administrador.

.PARAMETER DryRun
  Solo muestra lo que haria, sin actualizar.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tool\importar_coordenadas_localidades_excel.ps1 `
    -AdminEmail "correo@dominio.com" -AdminPassword "Clave123" -DryRun
#>

[CmdletBinding()]
param(
  [string]$Archivo = ".\Coordenadas_localidades.xlsx",
  [string]$Hoja = "Localidades",
  [string]$EnvFile = ".\env.json",
  [string]$TokenFile = ".\.supabase_token",
  [string]$AdminEmail = "",
  [string]$AdminPassword = "",
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$tmp = Join-Path $env:LOCALAPPDATA 'Temp\opencode'
if (-not (Test-Path $tmp)) { New-Item -ItemType Directory -Force -Path $tmp | Out-Null }
$inv = [System.Globalization.CultureInfo]::InvariantCulture

function ANumero($v) {
  if ($null -eq $v) { return $null }
  $t = ([string]$v).Trim()
  if ($t -eq '' -or $t -eq '-') { return $null }
  $t = $t -replace '\.', '' -replace ',', '.' -replace '\s', ''
  $n = 0.0
  if ([double]::TryParse($t, [System.Globalization.NumberStyles]::Float, $inv, [ref]$n)) { return $n }
  return $null
}

if (-not (Test-Path $Archivo)) { throw "No existe el archivo: $Archivo" }

# --- 1) Leer el Excel ---
Write-Host "Leyendo '$Archivo' (hoja '$Hoja')..."
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false; $excel.DisplayAlerts = $false
$wb = $excel.Workbooks.Open((Resolve-Path $Archivo).Path, $false, $true)
$ws = $wb.Worksheets.Item($Hoja)
$tot = $ws.UsedRange.Rows.Count
$totCol = $ws.UsedRange.Columns.Count

# Mapea los encabezados (primera fila) a indices de columna.
$colLocalidad = 0; $colLat = 0; $colLng = 0
for ($c = 1; $c -le $totCol; $c++) {
  $h = ([string]$ws.Cells.Item(1, $c).Text).Trim().ToUpper()
  if ($h -eq 'LOCALIDAD') { $colLocalidad = $c }
  elseif ($h -eq 'LAT' -or $h -eq 'LATITUD') { $colLat = $c }
  elseif ($h -eq 'LNG' -or $h -eq 'LON' -or $h -eq 'LONGITUD') { $colLng = $c }
}
if ($colLocalidad -eq 0 -or $colLat -eq 0 -or $colLng -eq 0) {
  throw "La hoja debe tener columnas LOCALIDAD, LAT y LNG."
}

$registros = New-Object System.Collections.ArrayList
for ($r = 2; $r -le $tot; $r++) {
  $loc = ([string]$ws.Cells.Item($r, $colLocalidad).Text).Trim()
  if ($loc -eq '') { continue }
  $lat = ANumero $ws.Cells.Item($r, $colLat).Text
  $lng = ANumero $ws.Cells.Item($r, $colLng).Text
  if ($null -eq $lat -or $null -eq $lng) { continue }
  if ($lat -lt -90 -or $lat -gt 90 -or $lng -lt -180 -or $lng -gt 180) {
    Write-Host "  fuera de rango: '$loc' ($lat, $lng)"
    continue
  }
  [void]$registros.Add([ordered]@{ localidad = $loc; lat = $lat; lng = $lng })
}
$wb.Close($false); $excel.Quit()
Write-Host "Localidades con coordenadas en el Excel: $($registros.Count)"

# --- 2) Conexion y token de admin ---
$envData = Get-Content -Raw $EnvFile | ConvertFrom-Json
$base = $envData.SUPABASE_URL
$anon = $envData.SUPABASE_ANON_KEY
if (-not $base -or -not $anon) { throw "Faltan SUPABASE_URL / SUPABASE_ANON_KEY en $EnvFile" }

$loginBody = @{ email = $AdminEmail; password = $AdminPassword } | ConvertTo-Json -Compress
[IO.File]::WriteAllText("$tmp\_login_coord.json", $loginBody, (New-Object System.Text.UTF8Encoding($false)))
$adm = curl.exe -s -X POST "$base/auth/v1/token?grant_type=password" -H "apikey: $anon" -H "Content-Type: application/json" --data-binary "@$tmp\_login_coord.json" | ConvertFrom-Json
if (-not $adm.access_token) { throw "No se pudo autenticar al administrador." }
$admTok = $adm.access_token

# --- 3) Mapa localidad -> id (sin distinguir mayusculas) ---
$todos = curl.exe -s "$base/rest/v1/fletes_tabulador?select=id,localidad" -H "apikey: $anon" -H "Authorization: Bearer $admTok" | ConvertFrom-Json
$mapa = @{}
foreach ($f in $todos) {
  if ($null -eq $f.localidad) { continue }
  $mapa[([string]$f.localidad).Trim().ToUpper()] = [string]$f.id
}
Write-Host "Localidades en el tabulador: $($mapa.Count)"

if ($DryRun) {
  Write-Host "DryRun: no se actualiza nada."
  Remove-Item "$tmp\_login_coord.json" -ErrorAction SilentlyContinue
  return
}

# --- 4) Actualizacion (solo lat/lng) ---
$ok = 0; $err = 0; $faltan = New-Object System.Collections.ArrayList
foreach ($reg in $registros) {
  $clave = $reg.localidad.Trim().ToUpper()
  if (-not $mapa.ContainsKey($clave)) {
    [void]$faltan.Add($reg.localidad)
    continue
  }
  $id = $mapa[$clave]
  $cuerpo = @{ lat = $reg.lat; lng = $reg.lng } | ConvertTo-Json -Compress
  [IO.File]::WriteAllText("$tmp\_coord.json", $cuerpo, (New-Object System.Text.UTF8Encoding($false)))
  $resp = curl.exe -s -w "`nHTTP %{http_code}" -X PATCH "$base/rest/v1/fletes_tabulador?id=eq.$id" -H "apikey: $anon" -H "Authorization: Bearer $admTok" -H "Content-Type: application/json" -H "Prefer: return=minimal" --data-binary "@$tmp\_coord.json"
  $code = ($resp -split "`n")[-1]
  if ($code -match '200|201|204') { $ok++ } else { $err++; Write-Host "  '$($reg.localidad)': $code :: $resp" }
}
Remove-Item "$tmp\_login_coord.json" -ErrorAction SilentlyContinue
Remove-Item "$tmp\_coord.json" -ErrorAction SilentlyContinue
Write-Host "Coordenadas actualizadas: ok=$ok err=$err"
if ($faltan.Count -gt 0) {
  Write-Host "No existen en el tabulador ($($faltan.Count)): $($faltan -join ', ')"
}
