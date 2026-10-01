<#
.SYNOPSIS
  Importa clientes desde un Excel (hoja con columnas CLIENTE, COD, CONTACTO,
  TELEFONO, EMAIL, DIRECCION, LAT, LONG, REGION) a la tabla `clientes` de
  Supabase.

.DESCRIPTION
  - Lee la hoja indicada y migra SOLO las filas con DIRECCION y REGION validas
    (no vacias y distintas de #N/D, #N/A, #VALUE!, #REF!).
  - Mapeo: CLIENTE->nombre, COD->cod_cli, CONTACTO->nombre_contacto,
    TELEFONO->telefono, EMAIL->email, DIRECCION->direccion, LAT->lat,
    LONG->lng; activo = true.
  - Limpieza: #N/D -> null; email en minusculas; coordenadas numericas
    (corrige latitudes sin punto decimal, p. ej. 10242273 -> 10.242273).
  - Regla de correo unico: en grupos con el mismo email, solo el primero lo
    conserva; el resto se inserta con email = null.
  - Idempotente: omite los cod_cli que ya existan en la tabla (y duplicados
    internos del propio Excel).

.PARAMETER Archivo
  Ruta del Excel. Por defecto: C:\Desarrollo\Coordenadas.xlsx

.PARAMETER Hoja
  Indice de la hoja (1 = primera). Por defecto: 1

.PARAMETER EnvFile
  JSON con SUPABASE_URL y SUPABASE_ANON_KEY. Por defecto: .\env.json (raiz).

.PARAMETER TokenFile
  Archivo con el PAT de Supabase para pedir el token de admin. Por defecto:
  .\.supabase_token

.PARAMETER AdminEmail / AdminPassword
  Credenciales del administrador para autenticar.

.PARAMETER DryRun
  Si se indica, no inserta: solo muestra lo que haria.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tool\importar_clientes_excel.ps1 `
    -Archivo "C:\Desarrollo\Coordenadas.xlsx" -Hoja 1 `
    -AdminEmail "correo@dominio.com" -AdminPassword "Clave123"
#>

[CmdletBinding()]
param(
  [string]$Archivo = "C:\Desarrollo\Coordenadas.xlsx",
  [int]$Hoja = 1,
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
  $t = ([string]$v).Trim() -replace '\s+', ' '
  if ($t -eq '' -or $t -in @('#N/D', '#N/A', '#VALUE!', '#REF!')) { return $null }
  return $t
}

function ANumero($v) {
  $t = ([string]$v).Trim() -replace '\s', ''
  if ($t -eq '' -or $t -eq '#N/D') { return $null }
  $n = 0.0
  if ([double]::TryParse($t, [System.Globalization.NumberStyles]::Float, $inv, [ref]$n)) { return $n }
  return $null
}

# Corrige latitudes tipo 10242273 -> 10.242273 (falta el punto decimal).
function CorrigeLat($n) {
  if ($null -eq $n) { return $null }
  if ($n -gt 90 -and $n -lt 999999999) {
    $s = ([string]$n) -replace '\.', ''
    if ($s.Length -ge 7 -and $s.StartsWith('10')) {
      return [double]::Parse(($s.Substring(0, 2) + '.' + $s.Substring(2)), $inv)
    }
  }
  return $n
}

if (-not (Test-Path $Archivo)) { throw "No existe el archivo: $Archivo" }

# --- 1) Leer el Excel ---
Write-Host "Leyendo '$Archivo' (hoja $Hoja)..."
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false; $excel.DisplayAlerts = $false
$wb = $excel.Workbooks.Open($Archivo, $false, $true)
$ws = $wb.Worksheets.Item($Hoja)
$total = $ws.UsedRange.Rows.Count

$registros = New-Object System.Collections.ArrayList
for ($r = 2; $r -le $total; $r++) {
  $dir = Limpio $ws.Cells.Item($r, 6).Text
  $reg = Limpio $ws.Cells.Item($r, 9).Text
  if ($null -eq $dir -or $null -eq $reg) { continue }   # exige DIRECCION y REGION
  $nombre = Limpio $ws.Cells.Item($r, 1).Text
  if ($null -eq $nombre) { continue }
  $em = Limpio $ws.Cells.Item($r, 5).Text
  if ($null -ne $em) { $em = $em.ToLower() }
  [void]$registros.Add([ordered]@{
    nombre          = $nombre
    cod_cli         = (Limpio $ws.Cells.Item($r, 2).Text)
    nombre_contacto = (Limpio $ws.Cells.Item($r, 3).Text)
    telefono        = (Limpio $ws.Cells.Item($r, 4).Text)
    email           = $em
    direccion       = $dir
    lat             = (CorrigeLat (ANumero $ws.Cells.Item($r, 7).Text))
    lng             = (ANumero $ws.Cells.Item($r, 8).Text)
    activo          = $true
  })
}
$wb.Close($false); $excel.Quit()
Write-Host "Filas con DIRECCION y REGION: $($registros.Count)"

# --- 2) Regla de email unico + dedup por cod_cli ---
$vE = @{}; $vC = @{}; $final = New-Object System.Collections.ArrayList
foreach ($reg in $registros) {
  if ($reg.email) {
    $k = $reg.email.ToLower()
    if ($vE.ContainsKey($k)) { $reg.email = $null } else { $vE[$k] = $true }
  }
  if ($reg.cod_cli) {
    $k = [string]$reg.cod_cli.Trim()
    if ($vC.ContainsKey($k)) { continue } else { $vC[$k] = $true }
  }
  [void]$final.Add($reg)
}
Write-Host "Registros finales: $($final.Count)"

# --- 3) Conexion y token de admin ---
$envData = Get-Content -Raw $EnvFile | ConvertFrom-Json
$base = $envData.SUPABASE_URL
$anon = $envData.SUPABASE_ANON_KEY
if (-not $base -or -not $anon) { throw "Faltan SUPABASE_URL / SUPABASE_ANON_KEY en $EnvFile" }

$loginBody = @{ email = $AdminEmail; password = $AdminPassword } | ConvertTo-Json -Compress
[IO.File]::WriteAllText("$tmp\_login.json", $loginBody, (New-Object System.Text.UTF8Encoding($false)))
$adm = curl.exe -s -X POST "$base/auth/v1/token?grant_type=password" -H "apikey: $anon" -H "Content-Type: application/json" --data-binary "@$tmp\_login.json" | ConvertFrom-Json
if (-not $adm.access_token) { throw "No se pudo autenticar al administrador." }
$admTok = $adm.access_token

# --- 4) Idempotencia: excluir cod_cli existentes ---
$existentes = curl.exe -s "$base/rest/v1/clientes?select=cod_cli" -H "apikey: $anon" -H "Authorization: Bearer $admTok" | ConvertFrom-Json
$setExist = @{}
foreach ($e in $existentes) { if ($e.cod_cli) { $setExist[[string]$e.cod_cli.Trim()] = $true } }
$nuevos = @($final | Where-Object { -not $_.cod_cli -or -not $setExist.ContainsKey([string]$_.cod_cli.Trim()) })
Write-Host "A insertar (nuevos): $($nuevos.Count)   (ya existentes: $($final.Count - $nuevos.Count))"

if ($DryRun) {
  Write-Host "DryRun: no se inserta nada."
  Remove-Item "$tmp\_login.json" -ErrorAction SilentlyContinue
  return
}

# --- 5) Insertar por lotes ---
$lote = 50; $i = 0; $ok = 0; $err = 0
while ($i -lt $nuevos.Count) {
  $chunk = @($nuevos[$i..([math]::Min($i + $lote - 1, $nuevos.Count - 1))])
  [IO.File]::WriteAllText("$tmp\_lote.json", ($chunk | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
  $resp = curl.exe -s -w "`nHTTP %{http_code}" -X POST "$base/rest/v1/clientes" -H "apikey: $anon" -H "Authorization: Bearer $admTok" -H "Content-Type: application/json" -H "Prefer: return=minimal" --data-binary "@$tmp\_lote.json"
  $code = ($resp -split "`n")[-1]
  if ($code -match '201|200') { $ok += $chunk.Count } else { $err += $chunk.Count; Write-Host "  Lote $i : $code :: $($resp.Substring(0,[math]::Min(200,$resp.Length)))" }
  $i += $lote
}
Write-Host "Insertados: $ok   Errores: $err"
Remove-Item "$tmp\_login.json", "$tmp\_lote.json" -ErrorAction SilentlyContinue
