import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
export declare class AuthService {
    private readonly prisma;
    private readonly jwtService;
    private readonly configService;
    constructor(prisma: PrismaService, jwtService: JwtService, configService: ConfigService);
    register(dto: RegisterDto): Promise<{
        accessToken: string;
        refreshToken: string;
        tokenType: string;
        expiresIn: string;
        user: {
            id: string;
            email: string;
            status: string;
            role: string;
            subscription: {
                id: string;
                userId: string;
                status: string;
                createdAt: Date;
                updatedAt: Date;
                planType: string;
                maxDevices: number;
                expiresAt: Date | null;
            };
        };
    }>;
    login(dto: LoginDto): Promise<{
        accessToken: string;
        refreshToken: string;
        tokenType: string;
        expiresIn: string;
        user: {
            id: string;
            email: string;
            status: string;
            role: string;
            subscription: {
                id: string;
                userId: string;
                status: string;
                createdAt: Date;
                updatedAt: Date;
                planType: string;
                maxDevices: number;
                expiresAt: Date | null;
            };
        };
    }>;
    refresh(dto: RefreshDto): Promise<{
        accessToken: string;
        refreshToken: string;
        tokenType: string;
        expiresIn: string;
    }>;
    getMe(userId: string): Promise<{
        activeSubscription: {
            id: string;
            userId: string;
            status: string;
            createdAt: Date;
            updatedAt: Date;
            planType: string;
            maxDevices: number;
            expiresAt: Date | null;
        };
        id: string;
        status: string;
        createdAt: Date;
        email: string;
        role: string;
        devices: {
            id: string;
            createdAt: Date;
            deviceIdentifier: string;
            name: string;
            platform: string;
            lastSeenAt: Date;
        }[];
        subscriptions: {
            id: string;
            userId: string;
            status: string;
            createdAt: Date;
            updatedAt: Date;
            planType: string;
            maxDevices: number;
            expiresAt: Date | null;
        }[];
    }>;
    private generateTokens;
}
