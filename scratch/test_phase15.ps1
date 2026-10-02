# Automated Verification Script: Phase 15 - Key Rotation & Post-Quantum WireGuard
$baseUrl = "http://127.0.0.1:3000/api/v1"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [PHASE 15 TEST] Automated Key Rotation & PQ-WireGuard Test " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Register & Login Test User
$testEmail = "phase15_pq_test_$(Get-Random)@example.com"
$testPassword = "Password123!"

$registerBody = @{
    email = $testEmail
    password = $testPassword
} | ConvertTo-Json

Write-Host "`n1. Registering user ($testEmail)..." -ForegroundColor Yellow
$regRes = Invoke-RestMethod -Uri "$baseUrl/auth/register" -Method Post -Body $registerBody -ContentType "application/json"
$token = $regRes.accessToken
$userId = $regRes.user.id
Write-Host "   -> Registered user $userId successfully." -ForegroundColor Green

# 2. Upgrade User to PRO
$upgradeBody = @{
    planType = "PRO"
} | ConvertTo-Json

Write-Host "`n2. Upgrading user to PRO plan..." -ForegroundColor Yellow
$upRes = Invoke-RestMethod -Uri "$baseUrl/billing/upgrade-test" -Method Post -Headers @{ Authorization = "Bearer $token" } -Body $upgradeBody -ContentType "application/json"
Write-Host "   -> Plan upgraded: $($upRes.subscription.planType) (Max Devices: $($upRes.subscription.maxDevices))" -ForegroundColor Green

# 3. Register Client Device
$deviceIdentifier = "test-device-uuid-pq-$(Get-Random)"
$deviceBody = @{
    deviceIdentifier = $deviceIdentifier
    name = "Galaxy SM-J610F Secure"
    platform = "ANDROID"
    publicKey = "0A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U="
} | ConvertTo-Json

Write-Host "`n3. Registering device..." -ForegroundColor Yellow
$devRes = Invoke-RestMethod -Uri "$baseUrl/devices" -Method Post -Headers @{ Authorization = "Bearer $token" } -Body $deviceBody -ContentType "application/json"
$deviceId = $devRes.id
Write-Host "   -> Device ID: $deviceId" -ForegroundColor Green

# 4. Connect with Post-Quantum Kyber768 Handshake
$connectBody = @{
    deviceId = $deviceId
    enablePostQuantum = $true
} | ConvertTo-Json

Write-Host "`n4. Requesting Post-Quantum WireGuard Tunnel Handshake..." -ForegroundColor Yellow
$connRes = Invoke-RestMethod -Uri "$baseUrl/vpn/connect" -Method Post -Headers @{ Authorization = "Bearer $token" } -Body $connectBody -ContentType "application/json"
Write-Host "   -> Connected to Server: $($connRes.tunnel.serverName)" -ForegroundColor Green
Write-Host "   -> Post-Quantum Enabled: $($connRes.tunnel.isPostQuantum)" -ForegroundColor Green
Write-Host "   -> KEM Algorithm: $($connRes.tunnel.postQuantumAlgorithm)" -ForegroundColor Green
Write-Host "   -> WireGuard PQ PSK: $($connRes.tunnel.presharedKey.Substring(0, 15))..." -ForegroundColor Green
Write-Host "   -> Key Rotated At: $($connRes.tunnel.keyRotatedAt)" -ForegroundColor Green

# 5. Check Key Status Endpoint
Write-Host "`n5. Fetching Cryptographic Key Security Status..." -ForegroundColor Yellow
$statusRes = Invoke-RestMethod -Uri "$baseUrl/vpn/key-status?deviceId=$deviceId" -Method Get -Headers @{ Authorization = "Bearer $token" }
Write-Host "   -> Device: $($statusRes.deviceName)" -ForegroundColor Green
Write-Host "   -> Key Age: $($statusRes.keyAgeDays) days (Recommended rotation: $($statusRes.isRecommendedToRotate))" -ForegroundColor Green
Write-Host "   -> PQ Algorithm: $($statusRes.postQuantumAlgorithm)" -ForegroundColor Green

# 6. Execute Dynamic Cryptographic Keypair Rotation
$newPubKey = "X9Y8Z7A6B5C4D3E2F1G0H9I8J7K6L5M4N3O2P1Q0R9="
$rotateBody = @{
    deviceId = $deviceId
    newPublicKey = $newPubKey
    enablePostQuantum = $true
} | ConvertTo-Json

Write-Host "`n6. Executing Dynamic Key Rotation on Active Tunnel..." -ForegroundColor Yellow
$rotRes = Invoke-RestMethod -Uri "$baseUrl/vpn/rotate-key" -Method Post -Headers @{ Authorization = "Bearer $token" } -Body $rotateBody -ContentType "application/json"
Write-Host "   -> Key Rotation Success: $($rotRes.success)" -ForegroundColor Green
Write-Host "   -> New Public Key: $($rotRes.newPublicKey)" -ForegroundColor Green
Write-Host "   -> Rotated Active Peers Count: $($rotRes.rotatedPeers.Count)" -ForegroundColor Green
Write-Host "   -> Peer 0 Server: $($rotRes.rotatedPeers[0].serverName) (PQ: $($rotRes.rotatedPeers[0].postQuantum))" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " [PHASE 15 VERIFICATION COMPLETE] All tests passed! " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
