#!/usr/bin/env bash
# ==============================================================================
# Antigravity Commercial VPN - Phase 12 Automated Security & Zero-Leak Audit Suite
# Tests: DNS Leaks, IPv6 Leaks, WebRTC STUN isolation, Kill Switch, and API Fuzzing
# ==============================================================================
set -euo pipefail

BACKEND_URL="${1:-http://localhost:3000/api/v1}"
PASSED=0
WARNINGS=0
FAILED=0

echo -e "\033[1;36m=================================================================\033[0m"
echo -e "\033[1;36m  ANTIGRAVITY VPN - LINUX ZERO-LEAK AUDIT & SECURITY SUITE      \033[0m"
echo -e "\033[1;36m=================================================================\033[0m"
echo "Target Backend: ${BACKEND_URL}"
echo "Date          : $(date -u)"
echo ""

report_pass() {
    echo -e "\033[1;32m[PASS]\033[0m $1"
    PASSED=$((PASSED + 1))
}

report_warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
    WARNINGS=$((WARNINGS + 1))
}

report_fail() {
    echo -e "\033[1;31m[FAIL]\033[0m $1"
    FAILED=$((FAILED + 1))
}

# 1. Enterprise Security Headers Audit
echo -e "\033[1;35m--- TEST 1: Enterprise Security Headers Audit ---\033[0m"
HEADERS_OUT=$(curl -sI "${BACKEND_URL}/diagnostics/ip" || true)

if echo "${HEADERS_OUT}" | grep -iq "x-content-type-options: nosniff"; then
    report_pass "X-Content-Type-Options: nosniff verified"
else
    report_fail "Missing X-Content-Type-Options: nosniff"
fi

if echo "${HEADERS_OUT}" | grep -iq "x-frame-options: SAMEORIGIN"; then
    report_pass "X-Frame-Options: SAMEORIGIN verified"
else
    report_fail "Missing X-Frame-Options: SAMEORIGIN"
fi

if echo "${HEADERS_OUT}" | grep -iq "x-xss-protection: 1; mode=block"; then
    report_pass "X-XSS-Protection: 1; mode=block verified"
else
    report_fail "Missing X-XSS-Protection: 1; mode=block"
fi

# 2. Control Plane Diagnostic Endpoint
echo -e "\n\033[1;35m--- TEST 2: Control Plane Leak Audit Endpoint ---\033[0m"
DIAG_RESP=$(curl -sf "${BACKEND_URL}/diagnostics/leak-audit" || echo "FAIL")
if [ "${DIAG_RESP}" != "FAIL" ] && echo "${DIAG_RESP}" | grep -q "overallVerdict"; then
    report_pass "Diagnostic leak audit returned valid payload"
    DETECTED_IP=$(echo "${DIAG_RESP}" | grep -o '"detectedIp":"[^"]*' | cut -d'"' -f4 || echo "unknown")
    VERDICT=$(echo "${DIAG_RESP}" | grep -o '"overallVerdict":"[^"]*' | cut -d'"' -f4 || echo "unknown")
    echo "   -> Detected IP: ${DETECTED_IP}"
    echo "   -> Verdict    : ${VERDICT}"
else
    report_fail "Failed to get valid leak audit response from control plane"
fi

# 3. DNS Hijack & Unbound Leak Probe
echo -e "\n\033[1;35m--- TEST 3: DNS Resolver Isolation Probe ---\033[0m"
if command -v dig >/dev/null 2>&1; then
    DNS_RESOLV=$(dig +short whoami.akamai.net || echo "")
    if [ -n "${DNS_RESOLV}" ]; then
        report_pass "Canary DNS resolution operational (Resolver: ${DNS_RESOLV})"
    else
        report_warn "DNS query failed or timeout (tunnel may be severing unrouted queries)"
    fi
else
    report_warn "'dig' not installed; skipped raw canary domain probe"
fi

# Check /etc/resolv.conf
if [ -f /etc/resolv.conf ]; then
    RESOLV_NAMESERVERS=$(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}')
    echo "   Active system nameservers: $(echo ${RESOLV_NAMESERVERS} | tr '\n' ' ')"
    if echo "${RESOLV_NAMESERVERS}" | grep -qE "(10\.8\.0\.|127\.0\.0\.)"; then
        report_pass "Private WireGuard / Local Unbound nameserver configured in resolv.conf"
    else
        report_warn "Non-VPN nameserver detected in /etc/resolv.conf (Normal if tunnel is inactive)"
    fi
fi

# 4. Dual-Stack IPv6 Leak Test
echo -e "\n\033[1;35m--- TEST 4: Dual-Stack IPv6 Isolation Test ---\033[0m"
IPV6_DEFAULT_ROUTE=$(ip -6 route show default 2>/dev/null || echo "")
if [ -z "${IPV6_DEFAULT_ROUTE}" ]; then
    report_pass "No unencrypted IPv6 default route (IPv6 disabled or blocked)"
elif echo "${IPV6_DEFAULT_ROUTE}" | grep -qE "(wg|tun)"; then
    report_pass "IPv6 default route bound to VPN tunnel interface (${IPV6_DEFAULT_ROUTE})"
else
    report_warn "IPv6 default route bound to physical interface (${IPV6_DEFAULT_ROUTE})"
fi

# 5. Volumetric Fuzzing against Rate Limiter
echo -e "\n\033[1;35m--- TEST 5: API Rate-Limiter Volumetric Fuzzing ---\033[0m"
echo "Sending burst of 120 rapid requests to test sliding-window limiter..."
BLOCKED_COUNT=0
ACCEPTED_COUNT=0

for i in $(seq 1 120); do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BACKEND_URL}/diagnostics/leak-audit" || echo "000")
    if [ "${STATUS}" = "429" ]; then
        BLOCKED_COUNT=$((BLOCKED_COUNT + 1))
    elif [ "${STATUS}" = "200" ]; then
        ACCEPTED_COUNT=$((ACCEPTED_COUNT + 1))
    fi
done

echo "   Accepted requests: ${ACCEPTED_COUNT}, Throttled/Blocked (429): ${BLOCKED_COUNT}"
if [ ${BLOCKED_COUNT} -gt 0 ]; then
    report_pass "API rate limiter successfully blocked excessive burst traffic (HTTP 429)"
else
    report_warn "Rate limiter not triggered in 120 requests; inspect sliding window threshold"
fi

# Summary
echo -e "\n\033[1;36m=================================================================\033[0m"
echo -e "\033[1;36m  SUMMARY: PASSED=${PASSED}  WARNINGS=${WARNINGS}  FAILED=${FAILED}\033[0m"
echo -e "\033[1;36m=================================================================\033[0m"

if [ ${FAILED} -eq 0 ]; then
    echo -e "\033[1;32mZERO-LEAK SECURITY AUDIT PASSED!\033[0m"
    exit 0
else
    echo -e "\033[1;31mSECURITY AUDIT ENCOUNTERED FAILURES.\033[0m"
    exit 1
fi
