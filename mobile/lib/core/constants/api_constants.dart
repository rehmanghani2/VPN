class ApiConstants {
  // Configurable via --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1
  // Defaults to localhost for Web & Desktop development
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000/api/v1',
  );

  // Auth Endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';

  // Device Endpoints
  static const String devices = '/devices';

  // VPN Endpoints
  static const String servers = '/vpn/servers';
  static const String connect = '/vpn/connect';
  static const String disconnect = '/vpn/disconnect';

  // Billing & Subscriptions
  static const String billingPlans = '/billing/plans';
  static const String billingSubscription = '/billing/subscription';
  static const String billingCheckout = '/billing/create-checkout-session';
  static const String billingVerifyReceipt = '/billing/verify-mobile-receipt';
  static const String billingUpgradeTest = '/billing/upgrade-test';

  // Speed Test & Threat Shield
  static const String speedtestPing = '/vpn/speedtest/ping';
  static const String speedtestDownload = '/vpn/speedtest/download';
  static const String speedtestUpload = '/vpn/speedtest/upload';
  static const String threatShieldStats = '/vpn/speedtest/threat-shield/stats';

  // Privacy & Zero-Leak Diagnostics
  static const String diagnosticsIp = '/diagnostics/ip';
  static const String diagnosticsLeakAudit = '/diagnostics/leak-audit';

  // Phase 13: Dedicated IP & Port Forwarding
  static const String portForwarding = '/port-forwarding';
  static const String dedicatedIp = '/dedicated-ip';
  static const String dedicatedIpAvailableRegions = '/dedicated-ip/available-regions';
  static const String dedicatedIpReserve = '/dedicated-ip/reserve';
  static const String dedicatedIpAssign = '/dedicated-ip/assign';

  // Phase 14: Multi-Hop (Double VPN) & Onion over VPN
  static const String multihopPairs = '/vpn/multihop/pairs';
  static const String multihopConnect = '/vpn/multihop/connect';
  static const String onionServers = '/vpn/onion/servers';

  // Phase 15: Post-Quantum WireGuard & Key Rotation
  static const String rotateKey = '/vpn/rotate-key';
  static const String keyStatus = '/vpn/key-status';
}
