import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding initial VPN platform data...');

  // 1. Create Admin User
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

  // 2. Seed Default Edge Servers
  const servers = [
    {
      name: 'Germany #1 - Frankfurt',
      countryCode: 'DE',
      countryName: 'Germany',
      city: 'Frankfurt',
      hostname: 'de1.vpnplatform.internal',
      publicIp: '198.51.100.10',
      wgPort: 51820,
      wgPublicKey: 'Yx0R7w0VvP+r/f01hZzGg5r4t8u7v6w5x4y3z2a1b0c=',
      status: 'ONLINE' as const,
      capacity: 500,
      currentLoad: 12,
      subnetV4: '10.8.0.0/24',
      dnsV4: '10.8.0.1',
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
      status: 'ONLINE' as const,
      capacity: 500,
      currentLoad: 34,
      subnetV4: '10.8.0.0/24',
      dnsV4: '10.8.0.1',
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
      status: 'ONLINE' as const,
      capacity: 500,
      currentLoad: 8,
      subnetV4: '10.8.0.0/24',
      dnsV4: '10.8.0.1',
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
