import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule);

  // Set global API prefix
  app.setGlobalPrefix('api/v1');

  // Enable request body validation & transformation
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  // Enable Cross-Origin Resource Sharing (CORS)
  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
  });

  // Security Headers & Rate Limiting Middleware
  const requestCounts = new Map<string, { count: number; resetTime: number }>();
  app.use((req: any, res: any, next: any) => {
    // 1. Enterprise Security Headers
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'SAMEORIGIN');
    res.setHeader('X-XSS-Protection', '1; mode=block');
    res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');

    // 2. Sliding Window Rate Limiting on sensitive and diagnostic endpoints
    const isSensitive = req.url.includes('/auth/') || req.url.includes('/vpn/connect');
    const isDiagnostic = req.url.includes('/diagnostics/');
    const shouldLimit = isSensitive || isDiagnostic;
    if (shouldLimit) {
      const clientIp = (req.headers['x-forwarded-for'] as string)?.split(',')[0].trim() || req.socket.remoteAddress || 'unknown';
      const now = Date.now();
      const clientData = requestCounts.get(clientIp);

      if (!clientData || now > clientData.resetTime) {
        requestCounts.set(clientIp, { count: 1, resetTime: now + 60000 });
      } else {
        clientData.count++;
        const maxLimit = isSensitive ? 30 : 60;
        if (clientData.count > maxLimit) {
          res.status(429).json({
            statusCode: 429,
            error: 'Too Many Requests',
            message: 'Rate limit exceeded. Please wait before retrying.',
          });
          return;
        }
      }
    }

    next();
  });

  const port = process.env.PORT || 3000;
  await app.listen(port);
  logger.log(`=======================================================`);
  logger.log(` Commercial VPN Control Plane API running on port ${port}`);
  logger.log(` Endpoint base: http://localhost:${port}/api/v1       `);
  logger.log(`=======================================================`);
}

bootstrap();
