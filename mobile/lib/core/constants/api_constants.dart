class ApiConstants {
  // Point this to your backend server IP/domain in production
  // Local backend URL for Web & Desktop
  static const String baseUrl = 'http://127.0.0.1:3000/api/v1';

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
}
