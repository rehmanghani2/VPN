const API_BASE = '/api/v1';

export function getStoredToken(): string {
  if (typeof window === 'undefined') return '';
  return localStorage.getItem('vpn_admin_token') || '';
}

export function setStoredToken(token: string) {
  if (typeof window !== 'undefined') {
    localStorage.setItem('vpn_admin_token', token);
  }
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getStoredToken();
  const headers = {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...options.headers,
  };

  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers,
  });

  if (!res.ok) {
    const errorData = await res.json().catch(() => ({}));
    throw new Error(errorData.message || `Request failed with status ${res.status}`);
  }

  return res.json();
}

export const api = {
  loginAdmin: async (email = 'admin@vpnplatform.internal', password = 'AdminSecurePass2026!') => {
    const res = await request<{ accessToken: string }>('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });
    setStoredToken(res.accessToken);
    return res;
  },

  getOverview: async () => {
    return request<{
      kpi: {
        totalUsers: number;
        totalDevices: number;
        activePeers: number;
        totalCapacity: number;
        clusterLoadPercent: number;
        estimatedBandwidthGbps: number;
      };
      servers: {
        total: number;
        online: number;
        draining: number;
        offline: number;
      };
      subscriptions: {
        total: number;
        breakdown: Record<string, number>;
      };
    }>('/admin/overview');
  },

  getServers: async () => {
    return request<Array<{
      id: string;
      name: string;
      countryCode: string;
      countryName: string;
      city: string;
      hostname: string;
      publicIp: string;
      wgPort: number;
      status: 'ONLINE' | 'DRAINING' | 'OFFLINE' | 'MAINTENANCE';
      capacity: number;
      currentLoad: number;
      loadPercent: number;
      isObfuscated: boolean;
      obfuscationPort: number;
      obfuscationProtocol: string;
    }>>('/admin/servers');
  },

  drainServer: async (serverId: string) => {
    return request(`/admin/servers/${serverId}/drain`, { method: 'POST' });
  },

  restoreServer: async (serverId: string) => {
    return request(`/admin/servers/${serverId}/restore`, { method: 'POST' });
  },

  getUsers: async (search?: string) => {
    const q = search ? `?search=${encodeURIComponent(search)}` : '';
    return request<Array<{
      id: string;
      email: string;
      role: string;
      status: string;
      createdAt: string;
      subscription: {
        planType: string;
        status: string;
        maxDevices: number;
        expiresAt: string | null;
      };
      devicesCount: number;
      activeSessionsCount: number;
      activeSessions: Array<{
        serverName: string;
        allocatedIp: string;
        updatedAt: string;
      }>;
    }>>(`/admin/users${q}`);
  },

  overrideUserPlan: async (userId: string, planType: string, maxDevices?: number) => {
    return request(`/admin/users/${userId}/override-plan`, {
      method: 'POST',
      body: JSON.stringify({ planType, maxDevices }),
    });
  },

  killUserSessions: async (userId: string) => {
    return request<{ success: boolean; terminatedCount: number }>(`/admin/users/${userId}/kill-sessions`, {
      method: 'POST',
    });
  },

  getAuditFeed: async () => {
    return request<Array<{
      id: string;
      event: string;
      server: string;
      device: string;
      allocatedIp: string;
      timestamp: string;
    }>>('/admin/audit-feed');
  },
};
