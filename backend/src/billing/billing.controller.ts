import {
  Controller,
  Get,
  Post,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
  Headers,
} from '@nestjs/common';
import { BillingService } from './billing.service';
import {
  CreateCheckoutSessionDto,
  VerifyMobileReceiptDto,
  UpgradeTestPlanDto,
} from './dto/billing.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('billing')
export class BillingController {
  constructor(private readonly billingService: BillingService) {}

  /**
   * Public/Client: List available subscription tiers
   */
  @Get('plans')
  async listPlans() {
    return this.billingService.getPlans();
  }

  /**
   * User: Get active subscription and quota consumption
   */
  @Get('subscription')
  @UseGuards(JwtAuthGuard)
  async getSubscription(@CurrentUser('id') userId: string) {
    return this.billingService.getUserSubscription(userId);
  }

  /**
   * User: Generate Checkout Session (Stripe/Web)
   */
  @Post('create-checkout-session')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async createCheckoutSession(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateCheckoutSessionDto,
  ) {
    return this.billingService.createCheckoutSession(userId, dto);
  }

  /**
   * User: Validate In-App Purchase (Google Play / Apple StoreKit)
   */
  @Post('verify-mobile-receipt')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async verifyMobileReceipt(
    @CurrentUser('id') userId: string,
    @Body() dto: VerifyMobileReceiptDto,
  ) {
    return this.billingService.verifyMobileReceipt(userId, dto);
  }

  /**
   * Stripe / Payment Webhook Receiver
   */
  @Post('webhook/stripe')
  @HttpCode(HttpStatus.OK)
  async handleStripeWebhook(
    @Body() event: any,
    @Headers('stripe-signature') signature?: string,
  ) {
    return this.billingService.handleStripeWebhook(event);
  }

  /**
   * Sandbox/Dev: Instant Plan Switcher
   */
  @Post('upgrade-test')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async upgradeTest(
    @CurrentUser('id') userId: string,
    @Body() dto: UpgradeTestPlanDto,
  ) {
    return this.billingService.upgradeTestPlan(userId, dto);
  }
}
