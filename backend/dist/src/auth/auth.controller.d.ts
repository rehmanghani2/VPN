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
            status: string;
            role: string;
            subscription: {
                id: string;
                status: string;
                createdAt: Date;
                updatedAt: Date;
                planType: string;
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
            status: string;
            role: string;
            subscription: {
                id: string;
                status: string;
                createdAt: Date;
                updatedAt: Date;
                planType: string;
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
            status: string;
            createdAt: Date;
            updatedAt: Date;
            planType: string;
            maxDevices: number;
            expiresAt: Date | null;
            userId: string;
        };
        id: string;
        email: string;
        status: string;
        role: string;
        createdAt: Date;
        devices: {
            id: string;
            createdAt: Date;
            name: string;
            deviceIdentifier: string;
            platform: string;
            lastSeenAt: Date;
        }[];
        subscriptions: {
            id: string;
            status: string;
            createdAt: Date;
            updatedAt: Date;
            planType: string;
            maxDevices: number;
            expiresAt: Date | null;
            userId: string;
        }[];
    }>;
}
