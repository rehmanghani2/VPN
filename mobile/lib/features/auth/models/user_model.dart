class UserModel {
  final String id;
  final String email;
  final String status;
  final String role;
  final String planType;
  final int maxDevices;

  UserModel({
    required this.id,
    required this.email,
    required this.status,
    required this.role,
    required this.planType,
    required this.maxDevices,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final sub = json['subscription'] ?? json['activeSubscription'];
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      role: json['role'] ?? 'USER',
      planType: sub?['planType'] ?? 'FREE',
      maxDevices: sub?['maxDevices'] ?? 1,
    );
  }
}
