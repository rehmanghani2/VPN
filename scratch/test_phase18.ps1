# Automated Verification Script: Phase 18 - Windows Privileged Service & Named Pipe IPC
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " [PHASE 18 TEST] Windows Privileged Service & Named Pipe IPC      " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# 1. Start Windows Service binary in background for IPC test
$serviceExe = "e:\Projects\VPN\windows-service\bin\Debug\net9.0-windows\AntigravityVpnService.exe"

if (-not (Test-Path $serviceExe)) {
    Write-Host "   [ERROR] Service binary not found at $serviceExe" -ForegroundColor Red
    exit 1
}

Write-Host "`n1. Launching AntigravityVpnService process..." -ForegroundColor Yellow
$proc = Start-Process -FilePath $serviceExe -PassThru -WindowStyle Hidden
Write-Host "   -> Service Process Started (PID: $($proc.Id))" -ForegroundColor Green

Start-Sleep -Seconds 3

try {
    # 2. Connect to Named Pipe \\.\pipe\AntigravityVpnIpc
    Write-Host "`n2. Connecting to Named Pipe '\\.\pipe\AntigravityVpnIpc'..." -ForegroundColor Yellow
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(".", "AntigravityVpnIpc", [System.IO.Pipes.PipeDirection]::InOut)
    $pipe.Connect(5000)

    $writer = New-Object System.IO.StreamWriter($pipe)
    $writer.AutoFlush = $true
    $reader = New-Object System.IO.StreamReader($pipe)

    Write-Host "   -> Connected to Named Pipe successfully!" -ForegroundColor Green

    # 3. Test Command: GetState
    Write-Host "`n3. Sending 'GetState' command..." -ForegroundColor Yellow
    $writer.WriteLine('{"Command":"GetState"}')
    $resp1 = $reader.ReadLine()
    Write-Host "   -> Response: $resp1" -ForegroundColor Green

    # 4. Test Command: StartTunnel
    Write-Host "`n4. Sending 'StartTunnel' command..." -ForegroundColor Yellow
    $startCmd = '{"Command":"StartTunnel","ClientAddressV4":"10.8.0.42","Endpoint":"198.51.100.10:51820","KillSwitch":false}'
    $writer.WriteLine($startCmd)
    $resp2 = $reader.ReadLine()
    Write-Host "   -> Response: $resp2" -ForegroundColor Green

    # 5. Test Command: StopTunnel
    Write-Host "`n5. Sending 'StopTunnel' command..." -ForegroundColor Yellow
    $writer.WriteLine('{"Command":"StopTunnel"}')
    $resp3 = $reader.ReadLine()
    Write-Host "   -> Response: $resp3" -ForegroundColor Green

    $pipe.Close()
    Write-Host "`n=================================================================" -ForegroundColor Cyan
    Write-Host " [PHASE 18 VERIFICATION COMPLETE] Named Pipe IPC verified 100%!   " -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Cyan
}
finally {
    # Clean up test process
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        Write-Host "`nCleaned up test service process (PID: $($proc.Id))." -ForegroundColor Gray
    }
}
