# Phase 17: Production Packaging, Docker Stack & Release Matrix

## 1. Overview & Objectives

Phase 17 hardens and automates deployment across all supported platforms (Android, Windows, Backend Cloud):
1. **Android Production Release Signing:** Configured secure `key.properties` loading with automatic fallback to debug keystore for development, while protecting credentials from Git exposure.
2. **Windows Desktop Packaging:** Authored an Inno Setup automated installer script (`setup.iss`) packaging the 64-bit Flutter release binary, icons, registry startup configuration, and Wintun driver.
3. **Containerized Production Stack:** Multi-stage minimal Node.js 20 Alpine container (`Dockerfile`), Caddy TLS reverse proxy (`Caddyfile`), and production orchestration (`docker-compose.prod.yml`).

---

## 2. Production Docker Architecture (`infrastructure/docker/`)

```
┌────────────────────────────────────────────────────────┐
│               Public Internet (HTTPS:443)              │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
              ┌───────────────────────────┐
              │   Caddy 2 Reverse Proxy   │ (Auto Let's Encrypt SSL,
              │     (vpn_caddy_gateway)   │  HSTS, security headers)
              └─────────────┬─────────────┘
                            │ /api/*
                            ▼
              ┌───────────────────────────┐
              │ NestJS 10 Control Plane   │ (dumb-init signal handling,
              │    (vpn_backend_prod)     │  non-root node user)
              └───────┬───────────┬───────┘
                      │           │
                      ▼           ▼
        ┌──────────────────┐ ┌──────────────────┐
        │  PostgreSQL 16   │ │     Redis 7      │
        │(vpn_postgres_prod│ │(vpn_redis_prod)  │
        └──────────────────┘ └──────────────────┘
```

---

## 3. Production Deliverables Matrix

| Component | Target Location | Description |
|---|---|---|
| **Android Keystore Template** | [`mobile/android/key.properties.example`](file:///e:/Projects/VPN/mobile/android/key.properties.example) | Keystore configuration template for Google Play / direct APK signing |
| **Android Gradle Signing** | [`mobile/android/app/build.gradle.kts`](file:///e:/Projects/VPN/mobile/android/app/build.gradle.kts) | Dynamic `signingConfigs.create("release")` with conditional fallback |
| **Windows Installer** | [`mobile/windows/installer/setup.iss`](file:///e:/Projects/VPN/mobile/windows/installer/setup.iss) | Inno Setup script compiling `AntigravityVPN_Installer_x64.exe` |
| **Backend Dockerfile** | [`backend/Dockerfile`](file:///e:/Projects/VPN/backend/Dockerfile) | Multi-stage production build container (builder + runner) |
| **Docker Compose Prod** | [`infrastructure/docker/docker-compose.prod.yml`](file:///e:/Projects/VPN/infrastructure/docker/docker-compose.prod.yml) | Orchestrates backend, postgres, redis, and caddy gateway |
| **Caddy TLS Proxy** | [`infrastructure/docker/Caddyfile`](file:///e:/Projects/VPN/infrastructure/docker/Caddyfile) | Automated HTTPS termination, HSTS, rate-limiting, and headers |

---

## 4. Verification

- `flutter analyze` completed with **0 issues found**.
- Android Gradle release signing configured without breaking debug builds.
- Production multi-stage Dockerfile and Docker Compose syntax verified.
