"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const core_1 = require("@nestjs/core");
const common_1 = require("@nestjs/common");
const app_module_1 = require("./app.module");
async function bootstrap() {
    const logger = new common_1.Logger('Bootstrap');
    const app = await core_1.NestFactory.create(app_module_1.AppModule);
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new common_1.ValidationPipe({
        whitelist: true,
        transform: true,
        forbidNonWhitelisted: true,
    }));
    app.enableCors({
        origin: '*',
        methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
        credentials: true,
    });
    const requestCounts = new Map();
    app.use((req, res, next) => {
        res.setHeader('X-Content-Type-Options', 'nosniff');
        res.setHeader('X-Frame-Options', 'SAMEORIGIN');
        res.setHeader('X-XSS-Protection', '1; mode=block');
        res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
        res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
        const isSensitive = req.url.includes('/auth/') || req.url.includes('/vpn/connect');
        const isDiagnostic = req.url.includes('/diagnostics/');
        const shouldLimit = isSensitive || isDiagnostic;
        if (shouldLimit) {
            const clientIp = req.headers['x-forwarded-for']?.split(',')[0].trim() || req.socket.remoteAddress || 'unknown';
            const now = Date.now();
            const clientData = requestCounts.get(clientIp);
            if (!clientData || now > clientData.resetTime) {
                requestCounts.set(clientIp, { count: 1, resetTime: now + 60000 });
            }
            else {
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
//# sourceMappingURL=main.js.map