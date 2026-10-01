import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateCheckoutSessionDto {
  @IsString()
  @IsNotEmpty()
  @IsIn(['PRO_MONTHLY', 'PRO_ANNUAL', 'FAMILY_ANNUAL'])
  planId: string;

  @IsString()
  @IsOptional()
  successUrl?: string;

  @IsString()
  @IsOptional()
  cancelUrl?: string;
}

export class VerifyMobileReceiptDto {
  @IsString()
  @IsNotEmpty()
  @IsIn(['GOOGLE_PLAY', 'APPLE_APP_STORE'])
  platform: 'GOOGLE_PLAY' | 'APPLE_APP_STORE';

  @IsString()
  @IsNotEmpty()
  productId: string;

  @IsString()
  @IsNotEmpty()
  purchaseToken: string;

  @IsString()
  @IsOptional()
  packageId?: string;
}

export class UpgradeTestPlanDto {
  @IsString()
  @IsNotEmpty()
  @IsIn(['FREE', 'PRO', 'FAMILY'])
  planType: 'FREE' | 'PRO' | 'FAMILY';
}
