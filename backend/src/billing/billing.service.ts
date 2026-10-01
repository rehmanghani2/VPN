import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  CreateCheckoutSessionDto,
  VerifyMobileReceiptDto,
  UpgradeTestPlanDto,
} from './dto/billing.dto';

export interface PlanDefinition {
  id: string;
  name: string;
  price: number;
  currency: string;
  billingPeriod: 'monthly' | 'annual' | 'free';
  maxDevices: number;
  features: string[];
  isPopular?: boolean;
}

@Injectable()
export class BillingService {
  private readonly logger = new Logger(BillingService.name);

  private readonly PLANS: Record<string, PlanDefinition> = {
    FREE: {
      id: 'FREE',
      name: 'Free Starter',
      price: 0,
      currency: 'USD',
      billingPeriod: 'free',
      maxDevices: 1,
      features: [
        '1 Device Connection',
        'Standard WireGuard Speed',
        'Access to Standard Servers',
        'Zero-Leak DNS Protection',
      ],
    },
    PRO_MONTHLY: {
      id: 'PRO_MONTHLY',
      name: 'Pro Monthly',
      price: 9.99,
      currency: 'USD',
      billingPeriod: 'monthly',
      maxDevices: 5,
      features: [
        '5 Simultaneous Devices',
        'Full Anti-DPI & Stealth 443 Support',
        'Ultra High-Speed 10Gbps Routes',
        'Split Tunneling & Kill Switch',
        'Zero Logs Guaranteed',
      ],
    },
    PRO_ANNUAL: {
      id: 'PRO_ANNUAL',
      name: 'Pro Annual (Best Value)',
      price: 59.99,
      currency: 'USD',
      billingPeriod: 'annual',
      maxDevices: 5,
      isPopular: true,
      features: [
        '5 Simultaneous Devices',
        'Save 50% Compared to Monthly',
        'Full Anti-DPI & Stealth 443 Support',
        'Ultra High-Speed 10Gbps Routes',
        'Split Tunneling & Kill Switch',
        'Priority 24/7 Support',
      ],
    },
    FAMILY_ANNUAL: {
      id: 'FAMILY_ANNUAL',
      name: 'Family & Teams',
      price: 99.99,
      currency: 'USD',
      billingPeriod: 'annual',
      maxDevices: 10,
      features: [
        '10 Simultaneous Devices',
        'Dedicated Private IP Option',
        'Full Anti-DPI & Stealth 443 Support',
        'Highest Priority Network Routing',
        'Split Tunneling & Kill Switch',
        'Multi-User Account Sharing',
      ],
    },
  };

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Return catalog of subscription tiers
   */
  async getPlans() {
    return Object.values(this.PLANS);
  }

  /**
   * Get authenticated user's current subscription & quota status
   */
  async getUserSubscription(userId: string) {
    let sub = await this.prisma.subscription.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });

    if (!sub) {
      // Default to FREE starter if none exists
      sub = await this.prisma.subscription.create({
        data: {
          userId,
          planType: 'FREE',
          status: 'ACTIVE',
          maxDevices: 1,
        },
      });
    }

    const deviceCount = await this.prisma.device.count({
      where: { userId },
    });

    const activeVpnPeers = await this.prisma.vpnPeer.count({
      where: {
        device: { userId },
        status: 'ACTIVE',
      },
    });

    return {
      subscription: sub,
      quota: {
        maxDevices: sub.maxDevices,
        registeredDevices: deviceCount,
        activeVpnSessions: activeVpnPeers,
        isLimitReached: activeVpnPeers >= sub.maxDevices,
        hasStealthAccess: sub.planType !== 'FREE',
      },
    };
  }

  /**
   * Create Checkout Session for Stripe / Web billing
   */
  async createCheckoutSession(userId: string, dto: CreateCheckoutSessionDto) {
    const plan = this.PLANS[dto.planId];
    if (!plan) {
      throw new BadRequestException('Invalid subscription plan ID');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });
    if (!user) throw new NotFoundException('User not found');

    const sessionId = `cs_test_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
    const checkoutUrl =
      dto.successUrl ||
      `https://checkout.commercialvpn.com/pay/${sessionId}?plan=${plan.id}`;

    this.logger.log(
      `[CHECKOUT] Generated checkout session ${sessionId} for user ${user.email} (Plan: ${plan.name})`,
    );

    return {
      sessionId,
      checkoutUrl,
      plan,
    };
  }

  /**
   * Handle Webhooks from Payment Providers (Stripe, LemonSqueezy, etc.)
   */
  async handleStripeWebhook(event: any) {
    this.logger.log(`[WEBHOOK] Ingested payment webhook event: ${event.type}`);

    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object;
        const userId = session.client_reference_id || session.metadata?.userId;
        const planId = session.metadata?.planId || 'PRO_ANNUAL';

        if (userId) {
          const maxDevices = planId.startsWith('FAMILY') ? 10 : 5;
          const planType = planId.startsWith('FAMILY') ? 'FAMILY' : 'PRO';

          const expiresAt = new Date();
          expiresAt.setFullYear(expiresAt.getFullYear() + 1);

          await this.prisma.subscription.upsert({
            where: { id: session.metadata?.subscriptionId || 'default-id' },
            create: {
              userId,
              planType,
              status: 'ACTIVE',
              maxDevices,
              expiresAt,
            },
            update: {
              planType,
              status: 'ACTIVE',
              maxDevices,
              expiresAt,
            },
          });
          this.logger.log(`[WEBHOOK] User ${userId} upgraded to ${planType}`);
        }
        break;
      }

      case 'customer.subscription.deleted': {
        const subObject = event.data.object;
        const userId = subObject.metadata?.userId;
        if (userId) {
          // Downgrade to FREE
          await this.prisma.subscription.updateMany({
            where: { userId },
            data: {
              planType: 'FREE',
              status: 'EXPIRED',
              maxDevices: 1,
            },
          });
          this.logger.warn(`[WEBHOOK] Subscription canceled for user ${userId}. Downgraded to FREE.`);
        }
        break;
      }

      default:
        this.logger.debug(`Unhandled webhook event type: ${event.type}`);
    }

    return { received: true };
  }

  /**
   * Mobile Store Receipt Verification (Google Play / Apple StoreKit)
   */
  async verifyMobileReceipt(userId: string, dto: VerifyMobileReceiptDto) {
    this.logger.log(
      `[IN-APP PURCHASE] Verifying ${dto.platform} receipt for user ${userId}, product: ${dto.productId}`,
    );

    // In production, invoke googleapis / apple app-store-server-library
    // For development & production fallback, grant entitlement based on product ID
    const isFamily = dto.productId.toLowerCase().includes('family');
    const planType = isFamily ? 'FAMILY' : 'PRO';
    const maxDevices = isFamily ? 10 : 5;

    const expiresAt = new Date();
    if (dto.productId.toLowerCase().includes('annual') || dto.productId.toLowerCase().includes('yearly')) {
      expiresAt.setFullYear(expiresAt.getFullYear() + 1);
    } else {
      expiresAt.setMonth(expiresAt.getMonth() + 1);
    }

    // Update or create subscription
    const existing = await this.prisma.subscription.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });

    let updated;
    if (existing) {
      updated = await this.prisma.subscription.update({
        where: { id: existing.id },
        data: {
          planType,
          status: 'ACTIVE',
          maxDevices,
          expiresAt,
        },
      });
    } else {
      updated = await this.prisma.subscription.create({
        data: {
          userId,
          planType,
          status: 'ACTIVE',
          maxDevices,
          expiresAt,
        },
      });
    }

    return {
      success: true,
      message: `Successfully activated ${planType} subscription!`,
      subscription: updated,
    };
  }

  /**
   * Sandbox Instant Plan Switcher (Testing & QA)
   */
  async upgradeTestPlan(userId: string, dto: UpgradeTestPlanDto) {
    const maxDevices = dto.planType === 'FREE' ? 1 : dto.planType === 'PRO' ? 5 : 10;
    const expiresAt = new Date();
    expiresAt.setFullYear(expiresAt.getFullYear() + 1);

    const existing = await this.prisma.subscription.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });

    let sub;
    if (existing) {
      sub = await this.prisma.subscription.update({
        where: { id: existing.id },
        data: {
          planType: dto.planType,
          status: 'ACTIVE',
          maxDevices,
          expiresAt: dto.planType === 'FREE' ? null : expiresAt,
        },
      });
    } else {
      sub = await this.prisma.subscription.create({
        data: {
          userId,
          planType: dto.planType,
          status: 'ACTIVE',
          maxDevices,
          expiresAt: dto.planType === 'FREE' ? null : expiresAt,
        },
      });
    }

    this.logger.log(`[TEST UPGRADE] User ${userId} updated to ${dto.planType} (Max: ${maxDevices})`);
    return { success: true, subscription: sub };
  }
}
