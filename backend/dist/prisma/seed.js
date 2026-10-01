"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@prisma/client");
const bcrypt = require("bcrypt");
const prisma = new client_1.PrismaClient();
async function main() {
    console.log('Seeding initial VPN platform data...');
    const adminEmail = 'admin@vpnplatform.internal';
    const existingAdmin = await prisma.user.findUnique({ where: { email: adminEmail } });
    if (!existingAdmin) {
        const salt = await bcrypt.genSalt(10);
        const passwordHash = await bcrypt.hash('AdminSecurePass2026!', salt);
        const admin = await prisma.user.create({
            data: {
                email: adminEmail,
                passwordHash,
                role: 'ADMIN',
                status: 'ACTIVE',
                subscriptions: {
                    create: {
                        planType: 'PREMIUM',
                        status: 'ACTIVE',
                        maxDevices: 10,
                    },
                },
            },
        });
        console.log(`Admin user created: ${admin.email}`);
    }
    const servers = [
        {
            name: 'Germany #1 - Frankfurt (Stealth Anti-DPI)',
            countryCode: 'DE',
            countryName: 'Germany',
            city: 'Frankfurt',
            hostname: 'de1.vpnplatform.internal',
            publicIp: '198.51.100.10',
            wgPort: 51820,
            wgPublicKey: 'Yx0R7w0VvP+r/f01hZzGg5r4t8u7v6w5x4y3z2a1b0c=',
            status: 'ONLINE',
            capacity: 500,
            currentLoad: 12,
            subnetV4: '10.8.0.0/24',
            dnsV4: '10.8.0.1',
            isObfuscated: true,
            obfuscationPort: 443,
            obfuscationProtocol: 'WIREGUARD_OBFUSCATED',
        },
        {
            name: 'USA #1 - New York',
            countryCode: 'US',
            countryName: 'United States',
            city: 'New York',
            hostname: 'us1.vpnplatform.internal',
            publicIp: '198.51.100.20',
            wgPort: 51820,
            wgPublicKey: 'Za1B2c3D4e5F6g7H8i9J0k1L2m3N4o5P6q7R8s9T0u1=',
            status: 'ONLINE',
            capacity: 500,
            currentLoad: 34,
            subnetV4: '10.8.0.0/24',
            dnsV4: '10.8.0.1',
            isObfuscated: false,
            obfuscationPort: 443,
            obfuscationProtocol: 'NONE',
        },
        {
            name: 'Singapore #1 - Jurong',
            countryCode: 'SG',
            countryName: 'Singapore',
            city: 'Singapore',
            hostname: 'sg1.vpnplatform.internal',
            publicIp: '198.51.100.30',
            wgPort: 51820,
            wgPublicKey: 'K1L2m3N4o5P6q7R8s9T0u1V2w3X4y5Z6a7B8c9D0e1f=',
            status: 'ONLINE',
            capacity: 500,
            currentLoad: 8,
            subnetV4: '10.8.0.0/24',
            dnsV4: '10.8.0.1',
            isObfuscated: false,
            obfuscationPort: 443,
            obfuscationProtocol: 'NONE',
        },
        {
            name: 'UK #1 - London (Camouflage TLS)',
            countryCode: 'GB',
            countryName: 'United Kingdom',
            city: 'London',
            hostname: 'uk1.vpnplatform.internal',
            publicIp: '198.51.100.40',
            wgPort: 51820,
            wgPublicKey: 'Uk1Mb25kb25TZWN1cmVLZXlGb3JDbGllbnRzMjAyNg==',
            status: 'ONLINE',
            capacity: 500,
            currentLoad: 19,
            subnetV4: '10.8.0.0/24',
            dnsV4: '10.8.0.1',
            isObfuscated: true,
            obfuscationPort: 443,
            obfuscationProtocol: 'SHADOWSOCKS_TLS',
        },
    ];
    for (const srv of servers) {
        const existing = await prisma.vpnServer.findFirst({
            where: { hostname: srv.hostname },
        });
        if (!existing) {
            await prisma.vpnServer.create({ data: srv });
            console.log(`VPN server seeded: ${srv.name}`);
        }
        else {
            await prisma.vpnServer.update({
                where: { id: existing.id },
                data: {
                    isObfuscated: srv.isObfuscated,
                    obfuscationPort: srv.obfuscationPort,
                    obfuscationProtocol: srv.obfuscationProtocol,
                },
            });
            console.log(`VPN server updated with obfuscation: ${srv.name}`);
        }
    }
    console.log('Seeding completed successfully.');
}
main()
    .catch((e) => {
    console.error('Seeding error:', e);
    process.exit(1);
})
    .finally(async () => {
    await prisma.$disconnect();
});
//# sourceMappingURL=seed.js.map