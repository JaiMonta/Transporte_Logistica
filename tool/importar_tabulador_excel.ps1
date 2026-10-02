<#
.SYNOPSIS
  Importa el tabulador de fletes desde un Excel a Supabase.

.DESCRIPTION
  - Hoja TABULADOR: por localidad (region, localidad, km y 10 precios por
    capacidad: 1,2 / 2,5 / 3,5 / 5 / 6 / 7,5 / 10 / 12 / 15 / 30 toneladas).
  - Hoja EXTRAS: parametros por capacidad (caleta, mora, reparto, desvio,
    fin de semana).
  - Los precios vienen en formato espanol ("1.059,00"): se normalizan.
  - Idempotente por localidad (upsert) y por capacidad en extras.

.PARAMETER Archivo
  Ruta del Excel. Por defecto: C:\Desarrollo\Tabulador.xlsx

.PARAMETER HojaTabulador / HojaExtras
  Nombres de las hojas. Por defecto: TABULADOR y EXTRAS.

.PARAMETER EnvFile / TokenFile
  env.json (SUPABASE_URL + anon key) y archivo con el PAT. Como en clientes.

.PARAMETER AdminEmail / AdminPassword
  Credenciales del administrador.

.PARAMETER DryRun
  Solo muestra lo que haria, sin insertar.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tool\importar_tabulador_excel.ps1 `
    -AdminEmail "correo@dominio.com" -AdminPassword "Clave123"
#>

[CmdletBinding()]
param(
  [string]$Archivo = "C:\Desarrollo\Tabulador.xlsx",
  [string]$HojaTabulador = "TABULADOR",
  [string]$HojaExtras = "EXTRAS",
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

function Limpio($v) {
  if ($null -eq $v) { return $null }
  $t = ([string]$v).Trim()
  if ($t -eq '' -or $t -eq '-') { return $null }
  return $t
}

# Convierte "1.059,00" o "39,48" o "10" a numero (cultura invariante).
function ANumero($v) {
  $t = Limpio $v
  if ($null -eq $t) { return $null }
  $t = $t -replace '\.', '' -replace ',', '.' -replace '\s', ''
  $n = 0.0
  if ([double]::TryParse($t, [System.Globalization.NumberStyles]::Float, $inv, [ref]$n)) { return $n }
  return $null
}

if (-not (Test-Path $Archivo)) { throw "No existe el archivo: $Archivo" }

# --- 1) Leer el Excel ---
Write-Host "Leyendo '$Archivo'..."
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false; $excel.DisplayAlerts = $false
$wb = $excel.Workbooks.Open($Archivo, $false, $true)

# Tabulador
$ws = $wb.Worksheets.Item($HojaTabulador)
$tot = $ws.UsedRange.Rows.Count
$registros = New-Object System.Collections.ArrayList
$regionActual = $null
for ($r = 1; $r -le $tot; $r++) {
  $c1 = Limpio $ws.Cells.Item($r, 1).Text
  if ($null -eq $c1) { continue }
  if ($c1 -match '^Regi[oó]n') { $regionActual = $c1; continue }
  if ($c1 -match 'NUEVO TABULADOR' -or $c1 -match '^KM$') { continue }
  # Fila de localidad
  [void]$registros.Add([ordered]@{
    region     = $regionActual
    localidad  = $c1
    km         = (ANumero $ws.Cells.Item($r, 2).Text)
    precio_1_2 = (ANumero $ws.Cells.Item($r, 3).Text)
    precio_2_5 = (ANumero $ws.Cells.Item($r, 4).Text)
    precio_3_5 = (ANumero $ws.Cells.Item($r, 5).Text)
    precio_5   = (ANumero $ws.Cells.Item($r, 6).Text)
    precio_6   = (ANumero $ws.Cells.Item($r, 7).Text)
    precio_7_5 = (ANumero $ws.Cells.Item($r, 8).Text)
    precio_10  = (ANumero $ws.Cells.Item($r, 9).Text)
    precio_12  = (ANumero $ws.Cells.Item($r, 10).Text)
    precio_15  = (ANumero $ws.Cells.Item($r, 11).Text)
    precio_30  = (ANumero $ws.Cells.Item($r, 12).Text)
  })
}
Write-Host "Localidades en el tabulador: $($registros.Count)"

# Extras
$we = $wb.Worksheets.Item($HojaExtras)
$totE = $we.UsedRange.Rows.Count
$extras = New-Object System.Collections.ArrayList
for ($r = 2; $r -le $totE; $r++) {
  $cap = ANumero $we.Cells.Item($r, 1).Text
  if ($null -eq $cap) { continue }
  [void]$extras.Add([ordered]@{
    capacidad_t = $cap
    caleta      = (ANumero $we.Cells.Item($r, 3).Text)
    mora        = (Limpio $we.Cells.Item($r, 4).Text)
    reparto     = (Limpio $we.Cells.Item($r, 5).Text)
    desvio      = (Limpio $we.Cells.Item($r, 6).Text)
    fin_semana  = (Limpio $we.Cells.Item($r, 7).Text)
  })
}
Write-Host "Filas de extras: $($extras.Count)"

$wb.Close($false); $excel.Quit()

# --- 2) Conexion y token de admin ---
$envData = Get-Content -Raw $EnvFile | ConvertFrom-Json
$base = $envData.SUPABASE_URL
$anon = $envData.SUPABASE_ANON_KEY
if (-not $base -or -not $anon) { throw "Faltan SUPABASE_URL / SUPABASE_ANON_KEY en $EnvFile" }

$loginBody = @{ email = $AdminEmail; password = $AdminPassword } | ConvertTo-Json -Compress
[IO.File]::WriteAllText("$tmp\_login_tab.json", $loginBody, (New-Object System.Text.UTF8Encoding($false)))
$adm = curl.exe -s -X POST "$base/auth/v1/token?grant_type=password" -H "apikey: $anon" -H "Content-Type: application/json" --data-binary "@$tmp\_login_tab.json" | ConvertFrom-Json
if (-not $adm.access_token) { throw "No se pudo autenticar al administrador." }
$admTok = $adm.access_token

if ($DryRun) {
  Write-Host "DryRun: no se inserta nada."
  Remove-Item "$tmp\_login_tab.json" -ErrorAction SilentlyContinue
  return
}

# --- 3) Upsert del tabulador (por localidad) ---
$okT = 0; $errT = 0
foreach ($reg in $registros) {
  [IO.File]::WriteAllText("$tmp\_tab.json", ($reg | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
  $resp = curl.exe -s -w "`nHTTP %{http_code}" -X POST "$base/rest/v1/fletes_tabulador?on_conflict=localidad" -H "apikey: $anon" -H "Authorization: Bearer $admTok" -H "Content-Type: application/json" -H "Prefer: resolution=merge-duplicates,return=minimal" --data-binary "@$tmp\_tab.json"
  $code = ($resp -split "`n")[-1]
  if ($code -match '201|200|204') { $okT++ } else { $errT++; Write-Host "  tab '$($reg.localidad)': $code :: $resp" }
}
Write-Host "Tabulador: ok=$okT err=$errT"

# --- 4) Upsert de extras (por capacidad) ---
$okE = 0; $errE = 0
foreach ($ex in $extras) {
  [IO.File]::WriteAllText("$tmp\_ex.json", ($ex | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
  $resp = curl.exe -s -w "`nHTTP %{http_code}" -X POST "$base/rest/v1/fletes_extras?on_conflict=capacidad_t" -H "apikey: $anon" -H "Authorization: Bearer $admTok" -H "Content-Type: application/json" -H "Prefer: resolution=merge-duplicates,return=minimal" --data-binary "@$tmp\_ex.json"
  $code = ($resp -split "`n")[-1]
  if ($code -match '201|200|204') { $okE++ } else { $errE++; Write-Host "  extras '$($ex.capacidad_t)': $code :: $resp" }
}
Write-Host "Extras: ok=$okE err=$errE"

Remove-Item "$tmp\_login_tab.json", "$tmp\_tab.json", "$tmp\_ex.json" -ErrorAction SilentlyContinue
