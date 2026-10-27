param([string]$KeilPath = 'C:\Keil_v5\UV4\UV4.exe')
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $KeilPath)) {
    throw 'Keil uVision was not found. Pass -KeilPath with the path to UV4.exe.'
}
$gameProject = Join-Path $PSScriptRoot 'MDK-ARM\nucleo_f413zh_game.uvprojx'
$gameLog = Join-Path $PSScriptRoot 'MDK-ARM\game_build.log'
$gameProcess = Start-Process -FilePath $KeilPath -ArgumentList @(
    '-r', ('"' + $gameProject + '"'), '-t', 'NUCLEO_F413ZH_GAME',
    '-o', ('"' + $gameLog + '"')
) -WindowStyle Hidden -Wait -PassThru
if (Test-Path -LiteralPath $gameLog) { Get-Content -LiteralPath $gameLog }
if ($gameProcess.ExitCode -ge 2) {
    throw ('Keil build failed with exit code ' + $gameProcess.ExitCode)
}
Write-Output ('Build complete; HEX: ' + (Join-Path $PSScriptRoot 'MDK-ARM\Objects\game\nucleo_f413zh_game.hex'))
