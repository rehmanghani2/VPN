"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DevicesService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
let DevicesService = class DevicesService {
    constructor(prisma) {
        this.prisma = prisma;
    }
    async listDevices(userId) {
        return this.prisma.device.findMany({
            where: { userId },
            orderBy: { lastSeenAt: 'desc' },
            include: {
                vpnPeers: {
                    select: {
                        id: true,
                        serverId: true,
                        allocatedIpV4: true,
                        status: true,
                        server: {
                            select: {
                                name: true,
                                countryCode: true,
                                city: true,
                            },
                        },
                    },
                },
            },
        });
    }
    async registerDevice(userId, dto) {
        const existing = await this.prisma.device.findUnique({
            where: {
                userId_deviceIdentifier: {
                    userId,
                    deviceIdentifier: dto.deviceIdentifier,
                },
            },
        });
        if (!existing) {
            const sub = await this.prisma.subscription.findFirst({
                where: { userId, status: 'ACTIVE' },
                orderBy: { createdAt: 'desc' },
            });
            const maxAllowed = sub ? sub.maxDevices : 1;
            const currentCount = await this.prisma.device.count({
                where: { userId },
            });
            if (currentCount >= maxAllowed) {
                throw new common_1.ForbiddenException(`Device limit reached (${maxAllowed} device maximum for your plan). Upgrade your plan or remove an existing device.`);
            }
        }
        return this.prisma.device.upsert({
            where: {
                userId_deviceIdentifier: {
                    userId,
                    deviceIdentifier: dto.deviceIdentifier,
                },
            },
            update: {
                name: dto.name,
                platform: dto.platform,
                publicKey: dto.publicKey,
                lastSeenAt: new Date(),
            },
            create: {
                userId,
                deviceIdentifier: dto.deviceIdentifier,
                name: dto.name,
                platform: dto.platform,
                publicKey: dto.publicKey,
            },
        });
    }
    async removeDevice(userId, deviceId) {
        const device = await this.prisma.device.findFirst({
            where: { id: deviceId, userId },
        });
        if (!device) {
            throw new common_1.NotFoundException('Device not found or not owned by user');
        }
        await this.prisma.device.delete({
            where: { id: deviceId },
        });
        return { message: 'Device successfully removed' };
    }
};
exports.DevicesService = DevicesService;
exports.DevicesService = DevicesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], DevicesService);
//# sourceMappingURL=devices.service.js.map