# Phase 2: Central Backend & Control Plane Specification

This document details the architecture, REST endpoints, database schema, and security flow for the NestJS Control Plane.

---

## 1. Architecture Overview

The backend controls device authentication, subscription entitlement, and WireGuard peer provisioning.

```
 Client (Mobile / Windows)
         │
         │ 1. POST /api/v1/auth/register or /login
         ▼
    Backend API ──> Issues JWT Access Token (15m) + Refresh Token (7d)
         │
         │ 2. POST /api/v1/devices (Uploads Device Public Key & Platform)
         ▼
    Backend API ──> Enforces Device Quota (Free=1, Basic=5, Premium=10)
         │
         │ 3. POST /api/v1/vpn/connect (Selects location or Smart Connect)
         ▼
    Backend API ──> Allocates IP from Server Pool (e.g. 10.8.0.42)
                ──> Emits complete WireGuard client configuration
```

---

## 2. API Endpoints Reference

Base URL: `http://localhost:3000/api/v1`

### Authentication (`/auth`)

#### `POST /auth/register`
- **Request Body:**
  ```json
  {
    "email": "user@example.com",
    "password": "Password123!"
  }
  ```
- **Response (`201 Created`):**
  ```json
  {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "status": "ACTIVE",
      "role": "USER",
      "subscription": {
        "planType": "FREE",
        "maxDevices": 1
      }
    },
    "accessToken": "ey...",
    "refreshToken": "ey...",
    "tokenType": "Bearer",
    "expiresIn": "15m"
  }
  ```

#### `POST /auth/login`
- **Request Body:**
  ```json
  {
    "email": "user@example.com",
    "password": "Password123!"
  }
  ```
- **Response (`200 OK`):** Same schema as register.

#### `POST /auth/refresh`
- **Request Body:**
  ```json
  {
    "refreshToken": "ey..."
  }
  ```
- **Response (`200 OK`):** Fresh `accessToken` and `refreshToken`.

#### `GET /auth/me` *(Requires Bearer Token)*
- Returns current user profile, active subscription status, and enrolled devices list.

---

### Device Management (`/devices`) *(Requires Bearer Token)*

#### `GET /devices`
- Returns all registered devices for the authenticated user and their active tunnels.

#### `POST /devices`
- **Request Body:**
  ```json
  {
    "deviceIdentifier": "unique-hardware-or-uuid",
    "name": "Samsung Galaxy S24",
    "platform": "ANDROID",
    "publicKey": "ClientWireGuardPublicKeyBase64="
  }
  ```
- **Quota Rule:** If the user has reached their plan's `maxDevices`, returns `403 Forbidden`.

#### `DELETE /devices/:id`
- Revokes device and cleans up associated WireGuard peer allocations.

---

### VPN Tunnel & Server Management (`/vpn`) *(Requires Bearer Token)*

#### `GET /vpn/servers`
- Returns the list of active servers with locations and current load:
  ```json
  [
    {
      "id": "uuid",
      "name": "Germany #1 - Frankfurt",
      "countryCode": "DE",
      "countryName": "Germany",
      "city": "Frankfurt",
      "status": "ONLINE",
      "capacity": 500,
      "currentLoad": 14
    }
  ]
  ```

#### `POST /vpn/connect`
- **Request Body:**
  ```json
  {
    "deviceId": "uuid",
    "serverId": "uuid" // Optional: omitted for Smart Connect (lowest load)
  }
  ```
- **Response (`200 OK`):**
  ```json
  {
    "tunnel": {
      "serverName": "Germany #1 - Frankfurt",
      "countryCode": "DE",
      "city": "Frankfurt",
      "endpoint": "198.51.100.10:51820",
      "serverPublicKey": "ServerWireGuardPublicKeyBase64=",
      "clientAddressV4": "10.8.0.2/24",
      "clientAddressV6": "fd42:42:42::2/64",
      "dns": ["10.8.0.1", "fd42:42:42::1"],
      "allowedIPs": ["0.0.0.0/0", "::/0"],
      "mtu": 1360,
      "keepalive": 25
    },
    "peerId": "uuid",
    "status": "CONNECTED"
  }
  ```

#### `POST /vpn/disconnect`
- **Request Body:**
  ```json
  {
    "deviceId": "uuid",
    "serverId": "uuid"
  }
  ```
- Marks peer as inactive and decreases server load.
