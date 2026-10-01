import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../auth/auth_provider.dart';
import '../models/subscription_plan.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  List<SubscriptionPlan> _plans = [];
  UserQuotaStatus? _quota;
  String _selectedPlanId = 'PRO_ANNUAL';

  @override
  void initState() {
    super.initState();
    _loadBillingData();
  }

  Future<void> _loadBillingData() async {
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();

    try {
      final plansRes = await api.client.get(ApiConstants.billingPlans);
      final quotaRes = await api.client.get(ApiConstants.billingSubscription);

      if (mounted) {
        setState(() {
          _plans = (plansRes.data as List<dynamic>)
              .map((p) => SubscriptionPlan.fromJson(p))
              .toList();
          _quota = UserQuotaStatus.fromJson(quotaRes.data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleUpgrade(String planId) async {
    setState(() => _isProcessing = true);
    final api = context.read<ApiService>();
    final auth = context.read<AuthProvider>();

    try {
      // Map planId to planType for upgrade
      String targetPlanType = 'PRO';
      if (planId == 'FREE') {
        targetPlanType = 'FREE';
      } else if (planId.startsWith('FAMILY')) {
        targetPlanType = 'FAMILY';
      }

      final res = await api.client.post(
        ApiConstants.billingUpgradeTest,
        data: {'planType': targetPlanType},
      );

      if (res.data['success'] == true) {
        await auth.refreshUser();
        await _loadBillingData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.connectedGreen,
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.black),
                  const SizedBox(width: 10),
                  Text(
                    'Unlocked $targetPlanType Plan successfully!',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.disconnectedRed,
            content: Text('Upgrade failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentPlan = auth.user?.planType ?? 'FREE';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Subscription'),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Header Banner
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primary.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      size: 64,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Unlock Total Freedom & Speed',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Unrestricted Anti-DPI Stealth, up to 10 simultaneous devices, and maximum 10Gbps bandwidth routes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary.withOpacity(0.85),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Current Plan Quota Card
                if (_quota != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _quota!.isLimitReached
                            ? AppTheme.disconnectedRed.withOpacity(0.5)
                            : AppTheme.surfaceLight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'CURRENT PLAN: ${_quota!.planType}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: AppTheme.primary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _quota!.hasStealthAccess
                                    ? AppTheme.connectedGreen.withOpacity(0.2)
                                    : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _quota!.hasStealthAccess
                                    ? '🥷 STEALTH UNLOCKED'
                                    : 'STANDARD SPEED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _quota!.hasStealthAccess
                                      ? AppTheme.connectedGreen
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Max Devices',
                                value: '${_quota!.maxDevices}',
                                icon: Icons.devices,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Active Sessions',
                                value:
                                    '${_quota!.activeVpnSessions} / ${_quota!.maxDevices}',
                                icon: Icons.router,
                                isWarning: _quota!.isLimitReached,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Plans Catalog
                const Text(
                  'SELECT SUBSCRIPTION TIER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                ..._plans.map((plan) {
                  final isSelected = _selectedPlanId == plan.id;
                  final isCurrent = (plan.id == 'FREE' && currentPlan == 'FREE') ||
                      (plan.id.startsWith('PRO') && (currentPlan == 'PRO' || currentPlan == 'PREMIUM')) ||
                      (plan.id.startsWith('FAMILY') && currentPlan == 'FAMILY');

                  return GestureDetector(
                    onTap: () => setState(() => _selectedPlanId = plan.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.surfaceLight,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          plan.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (plan.isPopular) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.connectedGreen
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              '50% OFF',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.connectedGreen,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (isCurrent) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                              color: AppTheme.primary
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'ACTIVE',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      plan.price == 0
                                          ? 'Free Forever'
                                          : '\$${plan.price.toStringAsFixed(2)} / ${plan.billingPeriod}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${plan.maxDevices} Dev',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20, color: AppTheme.surfaceLight),
                          ...plan.features.map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: AppTheme.connectedGreen,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      f,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary
                                            .withOpacity(0.9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // Upgrade Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _isProcessing
                        ? null
                        : () => _handleUpgrade(_selectedPlanId),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Activate ${_selectedPlanId.replaceAll('_', ' ')} Plan',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Cancel anytime. 30-day money-back guarantee.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary.withOpacity(0.6),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWarning
              ? AppTheme.disconnectedRed.withOpacity(0.4)
              : AppTheme.surfaceLight,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isWarning ? AppTheme.disconnectedRed : AppTheme.primary,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary.withOpacity(0.7),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isWarning ? AppTheme.disconnectedRed : Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
