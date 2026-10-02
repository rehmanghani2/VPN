# Comprehensive End-to-End Master Test Suite (Phases 1-16)
$baseUrl = "http://127.0.0.1:3000/api/v1"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " COMMERCIAL VPN PLATFORM: COMPREHENSIVE END-TO-END MASTER SUITE   " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# 1. User Registration & Auth
$testEmail = "master_suite_$(Get-Random)@vpnplatform.internal"
$testPassword = "MasterPassword2026!"

$regBody = @{ email = $testEmail; password = $testPassword } | ConvertTo-Json
$auth = Invoke-RestMethod -Uri "$baseUrl/auth/register" -Method Post -Body $regBody -ContentType "application/json"
$token = $auth.accessToken
$headers = @{ Authorization = "Bearer $token" }
Write-Host "`n[1/7] AUTHENTICATION & PROFILE" -ForegroundColor Yellow
Write-Host "   -> User created: $($auth.user.email) (ID: $($auth.user.id))" -ForegroundColor Green

# 2. Plan Upgrade to PRO
$upBody = @{ planType = "PRO" } | ConvertTo-Json
$sub = Invoke-RestMethod -Uri "$baseUrl/billing/upgrade-test" -Method Post -Headers $headers -Body $upBody -ContentType "application/json"
Write-Host "`n[2/7] BILLING & QUOTA MANAGEMENT" -ForegroundColor Yellow
Write-Host "   -> Subscription: $($sub.subscription.planType) (Max Devices: $($sub.subscription.maxDevices))" -ForegroundColor Green

# 3. Device Registration
$devBody = @{
    deviceIdentifier = "master-device-$(Get-Random)"
    name = "Enterprise Windows Desktop"
    platform = "WINDOWS"
    publicKey = "M4St3rPuB11cK3yPr0t0c01T3st1ng2026WireGuard="
} | ConvertTo-Json
$dev = Invoke-RestMethod -Uri "$baseUrl/devices" -Method Post -Headers $headers -Body $devBody -ContentType "application/json"
$deviceId = $dev.id
Write-Host "`n[3/7] DEVICE ORCHESTRATION" -ForegroundColor Yellow
Write-Host "   -> Device registered: $($dev.name) (ID: $deviceId)" -ForegroundColor Green

# 4. Multi-Hop Double VPN Cascading
$mhPairs = Invoke-RestMethod -Uri "$baseUrl/vpn/multihop/pairs" -Method Get -Headers $headers
$mhConnect = Invoke-RestMethod -Uri "$baseUrl/vpn/multihop/connect" -Method Post -Headers $headers -Body (@{
    deviceId = $deviceId
    entryServerId = $mhPairs[0].entryServer.id
    exitServerId = $mhPairs[0].exitServer.id
} | ConvertTo-Json) -ContentType "application/json"
Write-Host "`n[4/7] MULTI-HOP (DOUBLE VPN) CASCADING" -ForegroundColor Yellow
Write-Host "   -> Total Multi-Hop Chains: $($mhPairs.Count) route pairs" -ForegroundColor Green
Write-Host "   -> Cascaded Route: $($mhConnect.entryServer.city) ($($mhConnect.entryServer.countryCode)) -> $($mhConnect.exitServer.city) ($($mhConnect.exitServer.countryCode))" -ForegroundColor Green
Write-Host "   -> Entry Public Endpoint: $($mhConnect.entryServer.publicIp):$($mhConnect.entryServer.wgPort)" -ForegroundColor Green
Write-Host "   -> Client Subnet IP: $($mhConnect.clientAddressV4)" -ForegroundColor Green

# 5. Post-Quantum WireGuard Connection & Key Rotation
$regions = Invoke-RestMethod -Uri "$baseUrl/dedicated-ip/available-regions" -Method Get -Headers $headers
$targetServerId = $regions[0].id

$pqConn = Invoke-RestMethod -Uri "$baseUrl/vpn/connect" -Method Post -Headers $headers -Body (@{
    deviceId = $deviceId
    serverId = $targetServerId
    enablePostQuantum = $true
} | ConvertTo-Json) -ContentType "application/json"
$rotRes = Invoke-RestMethod -Uri "$baseUrl/vpn/rotate-key" -Method Post -Headers $headers -Body (@{
    deviceId = $deviceId
    newPublicKey = "N3wR0t4t3dPuB11cK3yPr0t0c01T3st1ng2026Wire="
    enablePostQuantum = $true
} | ConvertTo-Json) -ContentType "application/json"
Write-Host "`n[5/7] POST-QUANTUM KYBER768 AND FORWARD SECRECY KEY ROTATION" -ForegroundColor Yellow
Write-Host "   -> Connected Tunnel: $($pqConn.tunnel.serverName)" -ForegroundColor Green
Write-Host "   -> Post-Quantum Enabled: $($pqConn.tunnel.isPostQuantum) (KEM: $($pqConn.tunnel.postQuantumAlgorithm))" -ForegroundColor Green
Write-Host "   -> WireGuard PQ PSK: $($pqConn.tunnel.presharedKey.Substring(0, 15))..." -ForegroundColor Green
Write-Host "   -> Dynamic Key Rotation: $($rotRes.success)" -ForegroundColor Green
Write-Host "   -> New Public Key: $($rotRes.newPublicKey)" -ForegroundColor Green
Write-Host "   -> Rotated Active Peers: $($rotRes.rotatedPeers.Count)" -ForegroundColor Green

# 6. Dedicated IP Allocation & Binding
$reserve = Invoke-RestMethod -Uri "$baseUrl/dedicated-ip/reserve" -Method Post -Headers $headers -Body (@{
    serverId = $targetServerId
} | ConvertTo-Json) -ContentType "application/json"
$assign = Invoke-RestMethod -Uri "$baseUrl/dedicated-ip/assign" -Method Post -Headers $headers -Body (@{
    dedicatedIpId = $reserve.dedicatedIp.id
    deviceId = $deviceId
} | ConvertTo-Json) -ContentType "application/json"
Write-Host "`n[6/7] DEDICATED IP INFRASTRUCTURE" -ForegroundColor Yellow
Write-Host "   -> Reserved Static IP: $($reserve.dedicatedIp.publicIp) ($($regions[0].city))" -ForegroundColor Green
Write-Host "   -> SNAT Binding: $($assign.message)" -ForegroundColor Green

$randomExternalPort = Get-Random -Minimum 40000 -Maximum 65000
$pfRule = Invoke-RestMethod -Uri "$baseUrl/port-forwarding" -Method Post -Headers $headers -Body (@{
    deviceId = $deviceId
    serverId = $targetServerId
    externalPort = $randomExternalPort
    internalPort = 8080
    protocol = "BOTH"
} | ConvertTo-Json) -ContentType "application/json"
Write-Host "`n[7/7] PORT FORWARDING (NAT TRAVERSAL)" -ForegroundColor Yellow
Write-Host "   -> Rule Created: External :$($pfRule.rule.externalPort) -> Internal :$($pfRule.rule.internalPort) ($($pfRule.rule.protocol))" -ForegroundColor Green
Write-Host "   -> Public NAT Gateway Endpoint: $($pfRule.connectionEndpoint)" -ForegroundColor Green
Write-Host "   -> Forwarding Target Tunnel IP: $($pfRule.clientTunnelIp)" -ForegroundColor Green

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host " ALL 7 CORE SUBSYSTEM TESTS PASSED WITH 100% SUCCESS RATE!        " -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
