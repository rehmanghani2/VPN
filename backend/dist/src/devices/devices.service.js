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
var DevicesService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.DevicesService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
let DevicesService = DevicesService_1 = class DevicesService {
    constructor(prisma) {
        this.prisma = prisma;
        this.logger = new common_1.Logger(DevicesService_1.name);
    }
    async listDevices(userId) {
        const devices = await this.prisma.device.findMany({
            where: { userId },
            orderBy: { lastSeenAt: 'desc' },
            include: {
                vpnPeers: {
                    where: { status: 'ACTIVE' },
                    select: {
                        id: true,
                        serverId: true,
                        allocatedIpV4: true,
                        status: true,
                        updatedAt: true,
                        server: {
                            select: {
                                name: true,
                                countryCode: true,
                                city: true,
                                isObfuscated: true,
                            },
                        },
                    },
                },
            },
        });
        return devices.map((d) => ({
            id: d.id,
            name: d.name,
            platform: d.platform,
            deviceIdentifier: d.deviceIdentifier,
            lastSeenAt: d.lastSeenAt,
            isConnected: d.vpnPeers.length > 0,
            activeSession: d.vpnPeers[0] || null,
        }));
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
                throw new common_1.ForbiddenException(`Device limit reached (${maxAllowed} registered device limit for your plan). Upgrade to PRO or remove an existing device.`);
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
    async disconnectDevice(userId, deviceId) {
        const device = await this.prisma.device.findFirst({
            where: { id: deviceId, userId },
            include: {
                vpnPeers: {
                    where: { status: 'ACTIVE' },
                    include: { server: true },
                },
            },
        });
        if (!device) {
            throw new common_1.NotFoundException('Device not found or not owned by user');
        }
        for (const peer of device.vpnPeers) {
            await this.prisma.vpnPeer.update({
                where: { id: peer.id },
                data: { status: 'INACTIVE' },
            });
            await this.prisma.vpnServer.update({
                where: { id: peer.serverId },
                data: { currentLoad: { decrement: 1 } },
            });
            if (peer.server?.publicIp) {
                await this.syncPeerToNode(peer.server.publicIp, 'remove', {
                    publicKey: peer.clientPublicKey,
                });
            }
        }
        this.logger.log(`[DEVICE DISCONNECT] Device ${device.name} remote sessions terminated.`);
        return { success: true, message: `Device ${device.name} disconnected successfully` };
    }
    async removeDevice(userId, deviceId) {
        const device = await this.prisma.device.findFirst({
            where: { id: deviceId, userId },
        });
        if (!device) {
            throw new common_1.NotFoundException('Device not found or not owned by user');
        }
        await this.disconnectDevice(userId, deviceId);
        await this.prisma.device.delete({
            where: { id: deviceId },
        });
        return { success: true, message: 'Device successfully removed' };
    }
    async syncPeerToNode(serverIp, action, payload) {
        if (!serverIp || serverIp.startsWith('198.51.100.') || serverIp === '127.0.0.1') {
            return;
        }
        try {
            const agentPort = process.env.AGENT_PORT || 51821;
            const agentUrl = `http://${serverIp}:${agentPort}/peers/${action}`;
            const token = process.env.NODE_AGENT_TOKEN || 'vpn-node-agent-secure-token-2026';
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 2500);
            await fetch(agentUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-Node-Token': token,
                },
                body: JSON.stringify(payload),
                signal: controller.signal,
            });
            clearTimeout(timeoutId);
        }
        catch (err) {
            this.logger.warn(`[NodeAgent] Node sync ${serverIp} skipped: ${err.message}`);
        }
    }
};
exports.DevicesService = DevicesService;
exports.DevicesService = DevicesService = DevicesService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], DevicesService);
//# sourceMappingURL=devices.service.js.map