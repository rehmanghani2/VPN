class SubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final String currency;
  final String billingPeriod;
  final int maxDevices;
  final List<String> features;
  final bool isPopular;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.billingPeriod,
    required this.maxDevices,
    required this.features,
    this.isPopular = false,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
      billingPeriod: json['billingPeriod'] ?? 'monthly',
      maxDevices: json['maxDevices'] ?? 1,
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isPopular: json['isPopular'] ?? false,
    );
  }
}

class UserQuotaStatus {
  final int maxDevices;
  final int registeredDevices;
  final int activeVpnSessions;
  final bool isLimitReached;
  final bool hasStealthAccess;
  final String planType;

  UserQuotaStatus({
    required this.maxDevices,
    required this.registeredDevices,
    required this.activeVpnSessions,
    required this.isLimitReached,
    required this.hasStealthAccess,
    required this.planType,
  });

  factory UserQuotaStatus.fromJson(Map<String, dynamic> json) {
    final quota = json['quota'] ?? {};
    final sub = json['subscription'] ?? {};
    return UserQuotaStatus(
      maxDevices: quota['maxDevices'] ?? 1,
      registeredDevices: quota['registeredDevices'] ?? 0,
      activeVpnSessions: quota['activeVpnSessions'] ?? 0,
      isLimitReached: quota['isLimitReached'] ?? false,
      hasStealthAccess: quota['hasStealthAccess'] ?? false,
      planType: sub['planType'] ?? 'FREE',
    );
  }
}
