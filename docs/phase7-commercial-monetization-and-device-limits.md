# Phase 7: Commercial Monetization, Dynamic Quotas, & Multi-Device Enforcement

## 1. Overview & Architecture

Phase 7 implements the commercial monetization layer, multi-tier subscription engine, and strict multi-device concurrent session management required for an enterprise-tier consumer VPN (NordVPN / Proton VPN equivalent):

```
+---------------------------------------------------------------------------------------+
|                                    NestJS Backend                                     |
|                                                                                       |
|  +--------------------+   +-----------------------+   +----------------------------+  |
|  |   BillingModule    |   |     DevicesModule     |   |         VpnService         |  |
|  | - Plan Catalog     |   | - Device Registry     |   | - Dynamic Quota Limiting   |  |
|  | - Stripe Webhooks  |   | - Remote Disconnect   |   | - Session Auto-Eviction    |  |
|  | - Store Receipts   |   | - Node Agent Removal  |   | - Tier-gated Stealth 443   |  |
|  +--------------------+   +-----------------------+   +----------------------------+  |
+--------------------------^------------------------------------^-----------------------+
                           |                                    |
                           | HTTPS REST (JWT Bearer)            |
                           |                                    |
+--------------------------v------------------------------------v-----------------------+
|                                Flutter Multi-Platform App                             |
|                                                                                       |
|  +--------------------+   +-----------------------+   +----------------------------+  |
|  | SubscriptionScreen |   |     DevicesScreen     |   |   ServersScreen Gating     |  |
|  | - Plan Switcher    |   | - Active Session Badges|  | - Stealth 443 Locked for   |  |
|  | - Feature Matrix   |   | - Remote Disconnect   |   |   Free users with Upgrade  |  |
|  | - Instant Upgrade  |   | - Hardware Quota Bar  |   |   Action BottomSheet       |  |
|  +--------------------+   +-----------------------+   +----------------------------+  |
+---------------------------------------------------------------------------------------+
```

---

## 2. Subscription Tiers & Quota Specifications

| Plan Tier | Price / Term | Max Devices | Obfuscation / Stealth 443 | Network Priority | Dedicated IP |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **FREE Starter** | $0 | 1 Device | ❌ Locked (Standard only) | Standard | ❌ |
| **PRO Monthly** | $9.99 / mo | 5 Devices | ✅ Full Port 443 AmneziaWG | 10 Gbps Turbo | ❌ |
| **PRO Annual** | $59.99 / yr | 5 Devices | ✅ Full Port 443 AmneziaWG | 10 Gbps Turbo | ❌ |
| **FAMILY & Teams**| $99.99 / yr | 10 Devices | ✅ Full Port 443 AmneziaWG | Maximum Turbo | Optional |

---

## 3. Backend Endpoints

### 3.1 Billing & Subscriptions (`/api/v1/billing`)
- `GET /billing/plans`: Public endpoint returning tier catalog, prices, device allowances, and feature lists.
- `GET /billing/subscription`: Authenticated endpoint returning user plan, registered device count, active WireGuard peers, and quota headroom.
- `POST /billing/create-checkout-session`: Generates a Stripe Checkout session URL.
- `POST /billing/verify-mobile-receipt`: Verifies Google Play Billing (`purchaseToken`) and Apple StoreKit receipts and updates user subscription.
- `POST /billing/webhook/stripe`: Webhook processor handling `checkout.session.completed`, `customer.subscription.deleted`, and billing event lifecycle.
- `POST /billing/upgrade-test`: Developer and QA sandbox endpoint for instant plan switching.

### 3.2 Device Management (`/api/v1/devices`)
- `GET /devices`: Returns list of all user registered devices, their platform, last seen timestamp, active VPN sessions, and assigned tunnel IP.
- `POST /devices`: Upserts device hardware identifier and WireGuard public key (checks plan device limit).
- `POST /devices/:id/disconnect`: Remotely revokes active WireGuard sessions for that device on remote Linux edge nodes and decrements server load.
- `DELETE /devices/:id`: Deregisters the device and terminates any associated sessions.

### 3.3 Dynamic Quota Limiting & Graceful Session Auto-Eviction
In `VpnService.connect()`:
1. **Tier Gating**: Free tier users cannot connect to obfuscated nodes or use `stealth_obfuscated` protocol (`ForbiddenException: Stealth Anti-DPI servers require a PRO or FAMILY subscription`).
2. **Auto-Eviction of Oldest Sessions**: If a user on a 5-device plan initiates a connection from a 6th device, the platform automatically finds their oldest active tunnel session, marks it `INACTIVE`, calls the edge node daemon (`POST /peers/remove`) to revoke the peer, decrements node load, and cleanly activates the new session.

---

## 4. Flutter UI Implementation

1. **[`SubscriptionScreen`](file:///e:/Projects/VPN/mobile/lib/features/billing/screens/subscription_screen.dart)**:
   - Visual tier comparison cards with 50% OFF discount badges.
   - Interactive metric bar displaying Max Devices vs Active Sessions.
   - Feature checkmarks (Unlimited Bandwidth, Stealth 443 Camouflage, Zero-Leak Kill Switch).
   - Instant activation button.
2. **[`DevicesScreen`](file:///e:/Projects/VPN/mobile/lib/features/devices/screens/devices_screen.dart)**:
   - Overview progress bar showing registered devices against quota.
   - `THIS DEVICE` highlighted badge.
   - Live tunnel badges (`🟢 Connected to Germany #1 - Frankfurt (10.8.0.2)` vs `⚪ Idle`).
   - Remote tunnel disconnect and device removal modals.
3. **[`ServersScreen`](file:///e:/Projects/VPN/mobile/lib/features/vpn/screens/servers_screen.dart) Paywall Gating**:
   - If a Free user taps any `STEALTH 443` server, an animated bottom sheet prompts them with the feature explanation and direct upgrade action.
4. **[`SettingsScreen`](file:///e:/Projects/VPN/mobile/lib/features/settings/screens/settings_screen.dart)**:
   - Direct shortcuts for "Upgrade to Pro / Manage Subscription" and "Connected Devices & Sessions".
