# Phase 16: Smart Quality Prober & Auto-Failover Server Migration

## 1. Overview & Objectives

In production VPN environments, edge servers or ISP routing hops can suffer from sudden congestion, packet loss, or temporary degradation. Standard VPN clients freeze or silently stall connections until the user notices and manually disconnects.

**Phase 16 implements:**
1. **Continuous In-Tunnel Quality Prober:** An active telemetry monitor evaluating real-time round-trip latency, jitter, handshake freshness, and socket responsiveness every second.
2. **Spike & Degradation Detection Algorithm:** Evaluates consecutive high-latency occurrences ($\text{ping} > 220\text{ms}$ or stalled handshakes) over a sliding window.
3. **Seamless Auto-Failover Migration (`triggerFailoverMigration`):** Automatically selects the next lowest-load, lowest-latency server in the fleet, transitions the state machine to `reconnecting`, updates kernel/bridge parameters, and restores active tunneling with zero manual user interaction.
4. **User Experience & Telemetry Indicators:**
   - Real-time `reconnecting` indicator on the Home screen banner (**"AUTO-FAILOVER RECONNECTING..."**).
   - In-app toggle in Settings (**"Smart Auto-Failover"**).
   - Audit event dispatch into `DiagnosticsLogsScreen`.

---

## 2. Auto-Failover State Machine

```
┌───────────────────────┐
│     CONNECTED         │
│ (Active Tunnel Probe) │
└──────────┬────────────┘
           │ Ping > 220ms (Streak: 3/3)
           ▼
┌───────────────────────┐
│     RECONNECTING      │
│ (Failover In Flight)  │
├───────────────────────┤
│ • Fetch server catalog│
│ • Rank by load & ping │
│ • Re-negotiate keys   │
└──────────┬────────────┘
           │ Success
           ▼
┌───────────────────────┐
│     CONNECTED         │
│  (Optimal Node Active)│
└───────────────────────┘
```

---

## 3. Implementation Details

1. **`StorageService` (`mobile/lib/core/services/storage_service.dart`):**
   - Added `isAutoFailoverEnabled` (default `true`).
   - Added `failoverLatencyThresholdMs` (default `220ms`).

2. **`VpnProvider` (`mobile/lib/features/vpn/vpn_provider.dart`):**
   - Integrated quality prober in `_telemetryTimer`:
     ```dart
     if (_storage.isAutoFailoverEnabled && !_isFailingOver && _connectedDuration.inSeconds > 10) {
       final thresholdMs = _storage.failoverLatencyThresholdMs;
       if (ping > thresholdMs || (lastHandshake > 20 && _connectedDuration.inSeconds > 30)) {
         _consecutiveHighLatencyCount++;
         if (_consecutiveHighLatencyCount >= 3) {
           _consecutiveHighLatencyCount = 0;
           triggerFailoverMigration('Persistent latency spike ($ping ms > $thresholdMs ms)');
         }
       }
     }
     ```
   - Implemented `triggerFailoverMigration(reason)`.

3. **`HomeScreen` Banner Integration:**
   - Color shifts to amber `AppTheme.warningYellow` with pulsing indicator when failover migration is active.

4. **`SettingsScreen` UI:**
   - Dedicated toggle switch allowing users to enable or disable automatic failover.

---

## 4. Automated Verification

Executed `scratch/test_phase16.ps1`:
- User registered & device paired.
- Initial connection established to primary node (`Germany #1 - Frankfurt`).
- Simulated latency degradation event ($265\text{ms} > 220\text{ms}$).
- Candidate election algorithm selected lowest load node (`Singapore #1 - Jurong`).
- Executed migration and verified tunnel integrity.
- Verified `flutter analyze`: **0 issues found**.
