$ErrorActionPreference = 'Stop'

function Ensure-PathContains([string]$value) {
  if ([string]::IsNullOrWhiteSpace($value)) { return }
  if (($env:Path -split ';') -notcontains $value) {
    $env:Path = "$value;$env:Path"
  }
}

function Read-DotEnv([string]$filePath) {
  $values = @{}

  if (-not (Test-Path $filePath)) {
    return $values
  }

  foreach ($line in Get-Content $filePath) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
      continue
    }

    $parts = $trimmed -split '=', 2
    if ($parts.Count -ne 2) {
      continue
    }

    $key = $parts[0].Trim()
    $value = $parts[1].Trim()

    if (
      ($value.StartsWith('"') -and $value.EndsWith('"')) -or
      ($value.StartsWith("'") -and $value.EndsWith("'"))
    ) {
      $value = $value.Substring(1, $value.Length - 2)
    }

    $values[$key] = $value
  }

  return $values
}

function Write-DartDefineFile([hashtable]$defines) {
  $filtered = [ordered]@{}

  foreach ($entry in $defines.GetEnumerator()) {
    if (-not [string]::IsNullOrWhiteSpace($entry.Value)) {
      $filtered[$entry.Key] = $entry.Value
    }
  }

  if ($filtered.Count -eq 0) {
    return $null
  }

  $filePath = Join-Path $env:TEMP 'shaumsi_dart_defines.json'
  $filtered | ConvertTo-Json -Compress | Set-Content -Path $filePath -Encoding UTF8
  return $filePath
}

$flutterBin = 'C:\dev\flutter\bin'
$flutterCmd = Join-Path $flutterBin 'flutter.bat'
$projectRoot = Split-Path -Parent $PSScriptRoot
$dotenvValues = Read-DotEnv (Join-Path $projectRoot '.env')

if (-not (Test-Path $flutterCmd)) {
  throw "Flutter nao encontrado em $flutterCmd"
}

Ensure-PathContains $flutterBin

$javaHome = $env:JAVA_HOME
if ([string]::IsNullOrWhiteSpace($javaHome)) {
  $javaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
}
if ([string]::IsNullOrWhiteSpace($javaHome)) {
  $javaHome = (Get-ChildItem 'C:\dev\jdk' -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like 'jdk-17*' } |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1).FullName
}
if (-not [string]::IsNullOrWhiteSpace($javaHome) -and (Test-Path $javaHome)) {
  $env:JAVA_HOME = $javaHome
  Ensure-PathContains (Join-Path $javaHome 'bin')
}

$sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$platformTools = Join-Path $sdkRoot 'platform-tools'
$emulatorDir = Join-Path $sdkRoot 'emulator'

if (Test-Path $platformTools) { Ensure-PathContains $platformTools }
if (Test-Path $emulatorDir) { Ensure-PathContains $emulatorDir }

$preferredAvdName = 'ShauMsi_Lite_API_35'
$avdName = $preferredAvdName
$emulatorExe = Join-Path $emulatorDir 'emulator.exe'

$availableAvds = @()
if (Test-Path $emulatorExe) {
  $availableAvds = @(& $emulatorExe -list-avds 2>$null)
  if ($availableAvds -notcontains $preferredAvdName) {
    $fallbackAvd = $availableAvds |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      Select-Object -First 1
    if ($fallbackAvd) {
      $avdName = $fallbackAvd.Trim()
    }
  }
}

Write-Host '==> flutter pub get'
& $flutterCmd pub get

$deviceList = & adb devices
$runningEmulatorMatch = $deviceList | Select-String -Pattern '^emulator-[0-9]+\s+device$' | Select-Object -First 1

if (-not $runningEmulatorMatch) {
  Write-Host "==> Iniciando emulador: $avdName"
  if (-not (Test-Path $emulatorExe)) {
    throw "Emulator nao encontrado em $emulatorExe"
  }
  if ([string]::IsNullOrWhiteSpace($avdName)) {
    throw 'Nenhum AVD disponivel foi encontrado. Crie um emulador Android e tente novamente.'
  }

  Start-Process -FilePath $emulatorExe -ArgumentList @(
    '-avd', $avdName,
    '-gpu', 'angle_indirect',
    '-no-snapshot-load',
    '-no-snapshot-save',
    '-no-boot-anim',
    '-memory', '1536'
  )

  $maxAttempts = 120
  for ($i = 0; $i -lt $maxAttempts; $i++) {
    Start-Sleep -Seconds 2
    $deviceList = & adb devices
    $runningEmulatorMatch = $deviceList | Select-String -Pattern '^emulator-[0-9]+\s+device$' | Select-Object -First 1
    if ($runningEmulatorMatch) { break }
  }
}

if (-not $runningEmulatorMatch) {
  throw 'Nao consegui detectar o emulador Android online. Abra manualmente e tente novamente.'
}

$emulatorId = ($runningEmulatorMatch.ToString() -split "`t|\s+")[0]
Write-Host "==> Emulador detectado: $emulatorId"
Write-Host '==> Aguardando boot do Android...'

for ($i = 0; $i -lt 120; $i++) {
  Start-Sleep -Seconds 2
  $boot = (& adb -s $emulatorId shell getprop sys.boot_completed 2>$null).Trim()
  if ($boot -eq '1') { break }
}

$databaseUrl = if ($dotenvValues.ContainsKey('DATABASE_URL')) {
  $dotenvValues['DATABASE_URL']
} else {
  $env:DATABASE_URL
}

$databaseUrlUnpooled = if ($dotenvValues.ContainsKey('DATABASE_URL_UNPOOLED')) {
  $dotenvValues['DATABASE_URL_UNPOOLED']
} else {
  $env:DATABASE_URL_UNPOOLED
}

$runArgs = @('run', '-d', $emulatorId)
$dartDefineFile = Write-DartDefineFile @{
  DATABASE_URL = $databaseUrl
  DATABASE_URL_UNPOOLED = $databaseUrlUnpooled
}
if (-not [string]::IsNullOrWhiteSpace($dartDefineFile)) {
  $runArgs += "--dart-define-from-file=$dartDefineFile"
}

Write-Host "==> flutter $($runArgs -join ' ')"
& $flutterCmd @runArgs
