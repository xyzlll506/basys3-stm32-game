param([string]$KeilPath = 'C:\Keil_v5\UV4\UV4.exe')
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $KeilPath)) {
    throw 'Keil uVision was not found. Pass -KeilPath with the path to UV4.exe.'
}
$uartProject = Join-Path $PSScriptRoot 'MDK-ARM\nucleo_f413zh_uart.uvprojx'
$uartLog = Join-Path $PSScriptRoot 'MDK-ARM\build.log'
$uartProcess = Start-Process -FilePath $KeilPath -ArgumentList @(
    '-r', ('"' + $uartProject + '"'), '-t', 'NUCLEO_F413ZH_UART',
    '-o', ('"' + $uartLog + '"')
) -WindowStyle Hidden -Wait -PassThru
if (Test-Path -LiteralPath $uartLog) { Get-Content -LiteralPath $uartLog }
if ($uartProcess.ExitCode -ge 2) {
    throw ('Keil build failed with exit code ' + $uartProcess.ExitCode)
}
Write-Output ('Build complete; HEX: ' + (Join-Path $PSScriptRoot 'MDK-ARM\Objects\nucleo_f413zh_uart.hex'))
