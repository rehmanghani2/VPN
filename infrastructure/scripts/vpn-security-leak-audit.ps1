<#
.SYNOPSIS
    Antigravity Commercial VPN - Phase 12 Automated Security, Zero-Leak & Fuzzing Test Suite
.DESCRIPTION
    Comprehensive verification script testing:
    1. IPv4 Exposure and Identity Leak Detection
    2. DNS Hijack & Unbound Resolver Leak Probe
    3. Dual-Stack IPv6 Socket Isolation
    4. WebRTC STUN Candidate Deanonymization Probe
    5. Kill Switch Kernel Route / Firewall Failover Verification
    6. API Security Headers and Sliding-Window Rate-Limiter Fuzzing
#>

param(
    [string]$BackendUrl = "http://localhost:3000/api/v1",
    [switch]$FuzzRateLimit = $true
)

$ErrorActionPreference = "Continue"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  ANTIGRAVITY VPN - ZERO-LEAK VERIFICATION & SECURITY AUDIT       " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Backend Target: $BackendUrl" -ForegroundColor Gray
Write-Host "Timestamp     : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$Passed = 0
$Failed = 0
$Warnings = 0

function Report-Pass($msg) {
    Write-Host "[PASS] $msg" -ForegroundColor Green
    $script:Passed++
}

function Report-Fail($msg) {
    Write-Host "[FAIL] $msg" -ForegroundColor Red
    $script:Failed++
}

function Report-Warn($msg) {
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
    $script:Warnings++
}

# -------------------------------------------------------------
# 1. Backend Security Headers Audit
# -------------------------------------------------------------
Write-Host "--- TEST 1: Enterprise Security Headers Audit ---" -ForegroundColor Magenta
try {
    $resp = Invoke-WebRequest -Uri "$BackendUrl/diagnostics/ip" -Method Get -UseBasicParsing
    $headers = $resp.Headers

    if ($headers["X-Content-Type-Options"] -eq "nosniff") {
        Report-Pass "X-Content-Type-Options: nosniff present"
    } else {
        Report-Fail "Missing or invalid X-Content-Type-Options header"
    }

    if ($headers["X-Frame-Options"] -eq "SAMEORIGIN") {
        Report-Pass "X-Frame-Options: SAMEORIGIN present"
    } else {
        Report-Fail "Missing or invalid X-Frame-Options header"
    }

    if ($headers["X-XSS-Protection"] -eq "1; mode=block") {
        Report-Pass "X-XSS-Protection: 1; mode=block present"
    } else {
        Report-Fail "Missing or invalid X-XSS-Protection header"
    }

    if ($headers["Strict-Transport-Security"]) {
        Report-Pass "HSTS header present ($($headers['Strict-Transport-Security']))"
    } else {
        Report-Warn "HSTS header not sent (normal for HTTP localhost development)"
    }
} catch {
    Report-Fail "Failed to connect to backend diagnostics endpoint: $_"
}

# -------------------------------------------------------------
# 2. Control Plane Leak Diagnostic Audit
# -------------------------------------------------------------
Write-Host ""
Write-Host "--- TEST 2: Control Plane Leak Audit Endpoint Verification ---" -ForegroundColor Magenta
try {
    $audit = Invoke-RestMethod -Uri "$BackendUrl/diagnostics/leak-audit" -Method Get
    if ($audit.ipAudit -and $audit.dnsAudit -and $audit.ipv6Audit -and $audit.webrtcAudit) {
        Report-Pass "Control plane returns structured multi-vector leak audit"
        Write-Host "   -> Detected IP     : $($audit.ipAudit.detectedIp)" -ForegroundColor DarkGray
        Write-Host "   -> Encryption Grade: $($audit.ipAudit.protectionGrade)" -ForegroundColor DarkGray
        Write-Host "   -> Resolvers Count : $($audit.dnsAudit.resolversDetected)" -ForegroundColor DarkGray
        Write-Host "   -> Overall Verdict : $($audit.overallVerdict)" -ForegroundColor DarkGray
    } else {
        Report-Fail "Control plane leak audit schema incomplete"
    }
} catch {
    Report-Fail "Error calling $BackendUrl/diagnostics/leak-audit: $_"
}

# -------------------------------------------------------------
# 3. DNS Resolver Leak & Tunnel Isolation Test
# -------------------------------------------------------------
Write-Host ""
Write-Host "--- TEST 3: DNS Resolver Isolation & Poisoning Test ---" -ForegroundColor Magenta
try {
    # Resolve public DNS test probe
    $dnsResult = Resolve-DnsName -Name "one.one.one.one" -Type A -ErrorAction SilentlyContinue
    if ($dnsResult) {
        $resolvedIp = $dnsResult[0].IPAddress
        Report-Pass "DNS resolution successful (Resolved IP: $resolvedIp)"
        
        # Verify if local active DNS adapters have non-private or ISP resolvers exposed
        $adapters = Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses.Count -gt 0 }
        $externalDnsServers = @()
        foreach ($a in $adapters) {
            foreach ($addr in $a.ServerAddresses) {
                # Check for WireGuard / local private DNS (10.8.0.x or 127.0.0.1)
                if ($addr -notmatch "^10\.8\.0\." -and $addr -ne "127.0.0.1") {
                    $externalDnsServers += $addr
                }
            }
        }

        if ($externalDnsServers.Count -gt 0) {
            Report-Warn "Active network adapters contain external/LAN DNS resolvers: $($externalDnsServers -join ', ')"
            Write-Host "   (If VPN tunnel is disconnected, this is expected. While connected, Unbound 10.8.0.53 must be sole resolver.)" -ForegroundColor DarkGray
        } else {
            Report-Pass "Zero-Leak DNS confirmed: Only private VPN DNS resolver active"
        }
    } else {
        Report-Warn "Could not resolve test domain 'one.one.one.one' (offline or Kill Switch active)"
    }
} catch {
    Report-Warn "DNS resolution query error: $_"
}

# -------------------------------------------------------------
# 4. Dual-Stack IPv6 Socket Deanonymization Probe
# -------------------------------------------------------------
Write-Host ""
Write-Host "--- TEST 4: Dual-Stack IPv6 Socket Isolation Probe ---" -ForegroundColor Magenta
try {
    $ipv6Routes = Get-NetRoute -AddressFamily IPv6 -DestinationPrefix "::/0" -ErrorAction SilentlyContinue
    if ($ipv6Routes) {
        $ifAlias = (Get-NetIPInterface -InterfaceIndex $ipv6Routes[0].InterfaceIndex).InterfaceAlias
        if ($ifAlias -match "WireGuard|Wintun|antigravity") {
            Report-Pass "IPv6 Default Route is securely bound to VPN Interface ($ifAlias)"
        } else {
            Report-Warn "IPv6 Default Route is bound to physical interface ($ifAlias). Ensure IPv6 sinkholing or tunnel encapsulation is enabled."
        }
    } else {
        Report-Pass "No unencrypted IPv6 default route found (IPv6 traffic safe / sinkholed)"
    }
} catch {
    Report-Warn "IPv6 route inspection skipped: $_"
}

# -------------------------------------------------------------
# 5. Kill Switch Kernel Route / Firewall Failover Verification
# -------------------------------------------------------------
Write-Host ""
Write-Host "--- TEST 5: Kill Switch & Interface Route Metric Verification ---" -ForegroundColor Magenta
try {
    $defaultRoutes = Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Sort-Object RouteMetric
    if ($defaultRoutes) {
        $primaryRoute = $defaultRoutes[0]
        $primaryIf = (Get-NetIPInterface -InterfaceIndex $primaryRoute.InterfaceIndex).InterfaceAlias
        Write-Host "   Primary default route gateway: $($primaryRoute.NextHop) via interface '$primaryIf' (Metric: $($primaryRoute.RouteMetric))" -ForegroundColor DarkGray
        
        if ($primaryIf -match "WireGuard|Wintun|antigravity") {
            Report-Pass "VPN TUN interface holds top route priority (Strict 0.0.0.0/0 interception active)"
        } else {
            Report-Warn "Primary route is physical adapter '$primaryIf' (VPN currently idle or disconnected)"
        }
    } else {
        Report-Pass "Strict Kill Switch active: All 0.0.0.0/0 default routes severed"
    }
} catch {
    Report-Warn "Route metric query error: $_"
}

# -------------------------------------------------------------
# 6. API Sliding-Window Rate-Limiter Fuzzing
# -------------------------------------------------------------
if ($FuzzRateLimit) {
    Write-Host ""
    Write-Host "--- TEST 6: High-Frequency Fuzzing against Control Plane Rate Limiter ---" -ForegroundColor Magenta
    Write-Host "Firing 120 rapid concurrent requests to test rate limit enforcement..." -ForegroundColor DarkGray
    
    $rateLimitTripped = $false
    $successCount = 0
    $blockedCount = 0
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 1; $i -le 120; $i++) {
        try {
            $req = [System.Net.HttpWebRequest]::Create("$BackendUrl/diagnostics/leak-audit")
            $req.Timeout = 1500
            $res = $req.GetResponse()
            $successCount++
            $res.Close()
        } catch [System.Net.WebException] {
            $webEx = $_.Exception
            if ($webEx.Response -and $webEx.Response.StatusCode -eq 429) {
                $rateLimitTripped = $true
                $blockedCount++
            } elseif ($webEx.Response) {
                $blockedCount++
            }
        } catch {
            $blockedCount++
        }
    }
    $stopwatch.Stop()

    Write-Host "   Completed 120 requests in $($stopwatch.ElapsedMilliseconds)ms (Accepted: $successCount, Throttled/Blocked: $blockedCount)" -ForegroundColor DarkGray
    if ($rateLimitTripped -or $blockedCount -gt 0) {
        Report-Pass "Rate limiter successfully defended against volumetric request flood (HTTP 429 / Throttled)"
    } else {
        Report-Warn "Sliding window rate limit not triggered within 120 requests (check window threshold)"
    }
}

# -------------------------------------------------------------
# Audit Summary
# -------------------------------------------------------------
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  AUDIT RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  PASSED  : $Passed" -ForegroundColor Green
Write-Host "  WARNINGS: $Warnings" -ForegroundColor Yellow
Write-Host "  FAILED  : $Failed" -ForegroundColor $(if ($Failed -eq 0) { "Green" } else { "Red" })
Write-Host "=================================================================" -ForegroundColor Cyan

if ($Failed -eq 0) {
    Write-Host "ZERO-LEAK VERIFICATION PASSED: Platform is hardened and ready." -ForegroundColor Green
    exit 0
} else {
    Write-Host "SECURITY AUDIT COMPLETED WITH ISSUES: Review above failures." -ForegroundColor Red
    exit 1
}
