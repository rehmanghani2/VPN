import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
export declare class AuthController {
    private readonly authService;
    constructor(authService: AuthService);
    register(dto: RegisterDto): Promise<{
        accessToken: string;
        refreshToken: string;
        tokenType: string;
        expiresIn: string;
        user: {
            id: string;
            email: string;
            status: import(".prisma/client").$Enums.UserStatus;
            role: import(".prisma/client").$Enums.Role;
            subscription: {
                id: string;
                status: import(".prisma/client").$Enums.SubscriptionStatus;
                createdAt: Date;
                updatedAt: Date;
                planType: import(".prisma/client").$Enums.PlanType;
                maxDevices: number;
                expiresAt: Date | null;
                userId: string;
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
            status: import(".prisma/client").$Enums.UserStatus;
            role: import(".prisma/client").$Enums.Role;
            subscription: {
                id: string;
                status: import(".prisma/client").$Enums.SubscriptionStatus;
                createdAt: Date;
                updatedAt: Date;
                planType: import(".prisma/client").$Enums.PlanType;
                maxDevices: number;
                expiresAt: Date | null;
                userId: string;
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
            status: import(".prisma/client").$Enums.SubscriptionStatus;
            createdAt: Date;
            updatedAt: Date;
            planType: import(".prisma/client").$Enums.PlanType;
            maxDevices: number;
            expiresAt: Date | null;
            userId: string;
        };
        id: string;
        email: string;
        status: import(".prisma/client").$Enums.UserStatus;
        role: import(".prisma/client").$Enums.Role;
        createdAt: Date;
        devices: {
            id: string;
            createdAt: Date;
            name: string;
            deviceIdentifier: string;
            platform: import(".prisma/client").$Enums.Platform;
            lastSeenAt: Date;
        }[];
        subscriptions: {
            id: string;
            status: import(".prisma/client").$Enums.SubscriptionStatus;
            createdAt: Date;
            updatedAt: Date;
            planType: import(".prisma/client").$Enums.PlanType;
            maxDevices: number;
            expiresAt: Date | null;
            userId: string;
        }[];
    }>;
}
