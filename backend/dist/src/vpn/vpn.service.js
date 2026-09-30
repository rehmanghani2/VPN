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
exports.VpnService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
let VpnService = class VpnService {
    constructor(prisma) {
        this.prisma = prisma;
    }
    async listServers() {
        return this.prisma.vpnServer.findMany({
            where: {
                status: { in: ['ONLINE', 'DEGRADED'] },
            },
            select: {
                id: true,
                name: true,
                countryCode: true,
                countryName: true,
                city: true,
                hostname: true,
                status: true,
                capacity: true,
                currentLoad: true,
            },
            orderBy: [{ countryName: 'asc' }, { city: 'asc' }],
        });
    }
    async connect(userId, dto) {
        const device = await this.prisma.device.findFirst({
            where: { id: dto.deviceId, userId },
        });
        if (!device) {
            throw new common_1.NotFoundException('Device not found or not owned by user');
        }
        const subscription = await this.prisma.subscription.findFirst({
            where: { userId, status: 'ACTIVE' },
        });
        if (!subscription) {
            throw new common_1.ForbiddenException('An active subscription is required to connect');
        }
        let server = null;
        if (dto.serverId) {
            server = await this.prisma.vpnServer.findUnique({
                where: { id: dto.serverId },
            });
            if (!server || server.status === 'OFFLINE' || server.status === 'MAINTENANCE') {
                throw new common_1.BadRequestException('Selected VPN server is currently unavailable');
            }
        }
        else {
            server = await this.prisma.vpnServer.findFirst({
                where: { status: 'ONLINE' },
                orderBy: { currentLoad: 'asc' },
            });
            if (!server) {
                throw new common_1.NotFoundException('No available VPN servers found');
            }
        }
        let peer = await this.prisma.vpnPeer.findFirst({
            where: { deviceId: device.id, serverId: server.id },
        });
        if (!peer) {
            const allocatedIps = await this.prisma.vpnPeer.findMany({
                where: { serverId: server.id },
                select: { allocatedIpV4: true },
            });
            const usedOctets = new Set(allocatedIps.map((p) => {
                const parts = p.allocatedIpV4.split('.');
                return parseInt(parts[3], 10);
            }));
            let allocatedOctet = -1;
            for (let i = 2; i <= 254; i++) {
                if (!usedOctets.has(i)) {
                    allocatedOctet = i;
                    break;
                }
            }
            if (allocatedOctet === -1) {
                throw new common_1.BadRequestException('Server capacity reached: no available IP slots');
            }
            const clientIpV4 = `10.8.0.${allocatedOctet}`;
            const clientIpV6 = `fd42:42:42::${allocatedOctet}`;
            peer = await this.prisma.vpnPeer.create({
                data: {
                    deviceId: device.id,
                    serverId: server.id,
                    allocatedIpV4: clientIpV4,
                    allocatedIpV6: clientIpV6,
                    clientPublicKey: device.publicKey,
                    status: 'ACTIVE',
                },
            });
            await this.prisma.vpnServer.update({
                where: { id: server.id },
                data: { currentLoad: { increment: 1 } },
            });
        }
        else {
            peer = await this.prisma.vpnPeer.update({
                where: { id: peer.id },
                data: {
                    clientPublicKey: device.publicKey,
                    status: 'ACTIVE',
                },
            });
        }
        await this.prisma.device.update({
            where: { id: device.id },
            data: { lastSeenAt: new Date() },
        });
        return {
            tunnel: {
                serverName: server.name,
                countryCode: server.countryCode,
                city: server.city,
                endpoint: `${server.publicIp}:${server.wgPort}`,
                serverPublicKey: server.wgPublicKey,
                clientAddressV4: `${peer.allocatedIpV4}/24`,
                clientAddressV6: `${peer.allocatedIpV6}/64`,
                dns: [server.dnsV4, server.dnsV6],
                allowedIPs: ['0.0.0.0/0', '::/0'],
                mtu: 1360,
                keepalive: 25,
            },
            peerId: peer.id,
            status: 'CONNECTED',
        };
    }
    async disconnect(userId, dto) {
        const device = await this.prisma.device.findFirst({
            where: { id: dto.deviceId, userId },
        });
        if (!device) {
            throw new common_1.NotFoundException('Device not found');
        }
        const whereClause = { deviceId: device.id, status: 'ACTIVE' };
        if (dto.serverId) {
            whereClause.serverId = dto.serverId;
        }
        const activePeers = await this.prisma.vpnPeer.findMany({
            where: whereClause,
        });
        for (const peer of activePeers) {
            await this.prisma.vpnPeer.update({
                where: { id: peer.id },
                data: { status: 'INACTIVE' },
            });
            await this.prisma.vpnServer.update({
                where: { id: peer.serverId },
                data: { currentLoad: { decrement: 1 } },
            });
        }
        return { message: 'Disconnected successfully' };
    }
};
exports.VpnService = VpnService;
exports.VpnService = VpnService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], VpnService);
//# sourceMappingURL=vpn.service.js.map