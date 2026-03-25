$ErrorActionPreference = 'Stop'

function Ensure-PathContains([string]$value) {
  if ([string]::IsNullOrWhiteSpace($value)) { return }
  if (($env:Path -split ';') -notcontains $value) {
    $env:Path = "$value;$env:Path"
  }
}

$flutterBin = 'C:\dev\flutter\bin'
$flutterCmd = Join-Path $flutterBin 'flutter.bat'

if (-not (Test-Path $flutterCmd)) {
  throw "Flutter não encontrado em $flutterCmd"
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

$avdName = 'Miwanzo_Lite_API_35'
$emulatorExe = Join-Path $emulatorDir 'emulator.exe'

Write-Host '==> flutter pub get'
& $flutterCmd pub get

$deviceList = & adb devices
$runningEmulatorMatch = $deviceList | Select-String -Pattern '^emulator-[0-9]+\s+device$' | Select-Object -First 1

if (-not $runningEmulatorMatch) {
  Write-Host "==> Iniciando emulador: $avdName"
  if (-not (Test-Path $emulatorExe)) {
    throw "Emulator não encontrado em $emulatorExe"
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
  throw 'Não consegui detectar o emulador Android online. Abra manualmente e tente novamente.'
}

$emulatorId = ($runningEmulatorMatch.ToString() -split "`t|\s+")[0]
Write-Host "==> Emulador detectado: $emulatorId"
Write-Host '==> Aguardando boot do Android...'

for ($i = 0; $i -lt 120; $i++) {
  Start-Sleep -Seconds 2
  $boot = (& adb -s $emulatorId shell getprop sys.boot_completed 2>$null).Trim()
  if ($boot -eq '1') { break }
}

Write-Host "==> flutter run -d $emulatorId"
& $flutterCmd run -d $emulatorId
