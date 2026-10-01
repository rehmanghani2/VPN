import {
  Controller,
  Get,
  Req,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { Request } from 'express';
import { DiagnosticsService } from './diagnostics.service';

@Controller('diagnostics')
export class DiagnosticsController {
  constructor(private readonly diagnosticsService: DiagnosticsService) {}

  /**
   * Quick IP & VPN Tunnel Status Check
   */
  @Get('ip')
  @HttpCode(HttpStatus.OK)
  async checkIp(@Req() req: Request) {
    const clientIp =
      (req.headers['x-forwarded-for'] as string)?.split(',')[0].trim() ||
      req.socket.remoteAddress ||
      '127.0.0.1';
    return this.diagnosticsService.checkIpLeak(clientIp);
  }

  /**
   * Comprehensive Zero-Leak Privacy Audit (DNS, WebRTC, IPv6)
   */
  @Get('leak-audit')
  @HttpCode(HttpStatus.OK)
  async runAudit(@Req() req: Request) {
    const clientIp =
      (req.headers['x-forwarded-for'] as string)?.split(',')[0].trim() ||
      req.socket.remoteAddress ||
      '127.0.0.1';
    return this.diagnosticsService.runFullLeakAudit(clientIp);
  }
}
