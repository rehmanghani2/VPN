import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';

@Injectable()
export class NodeTokenGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<Request>();
    const token = request.headers['x-node-token'];
    const expectedToken =
      process.env.NODE_AGENT_TOKEN || 'vpn-node-agent-secure-token-2026';

    if (!token || token !== expectedToken) {
      throw new UnauthorizedException('Invalid or missing X-Node-Token header');
    }

    return true;
  }
}
