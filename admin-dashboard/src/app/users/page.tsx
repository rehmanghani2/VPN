'use client';

import React, { useEffect, useState } from 'react';
import { Header } from '../../components/Header';
import { api } from '../../lib/api';
import { Search, ShieldAlert, Sparkles, Smartphone, Power } from 'lucide-react';

export default function UsersPage() {
  const [users, setUsers] = useState<any[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);

  const loadUsers = async () => {
    setLoading(true);
    try {
      const data = await api.getUsers(search);
      setUsers(data);
    } catch (_) {
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadUsers();
  }, []);

  const handleOverridePlan = async (userId: string, currentPlan: string) => {
    const newPlan = prompt('Enter new subscription plan (FREE, PRO, FAMILY):', currentPlan);
    if (!newPlan) return;

    try {
      await api.overrideUserPlan(userId, newPlan.toUpperCase());
      alert(`User plan successfully updated to ${newPlan.toUpperCase()}`);
      loadUsers();
    } catch (e: any) {
      alert('Plan update failed: ' + e.message);
    }
  };

  const handleKillSessions = async (userId: string, email: string) => {
    if (!confirm(`Are you sure you want to terminate all active WireGuard sessions for ${email}?`)) {
      return;
    }

    try {
      const res = await api.killUserSessions(userId);
      alert(`Terminated ${res.terminatedCount} active VPN sessions.`);
      loadUsers();
    } catch (e: any) {
      alert('Killswitch failed: ' + e.message);
    }
  };

  return (
    <div>
      <Header
        title="User Management"
        subtitle="Customer subscription plans, hardware devices, and active session controls"
      />

      <div className="bg-surface border border-border rounded-2xl p-6">
        {/* Search Bar */}
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 mb-6">
          <div className="relative w-full sm:w-96">
            <Search className="w-4 h-4 text-text-muted absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Search user by email address..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && loadUsers()}
              className="w-full bg-background border border-border pl-10 pr-4 py-2 text-xs rounded-xl text-white outline-none focus:border-primary transition-all"
            />
          </div>

          <button
            onClick={loadUsers}
            className="w-full sm:w-auto px-4 py-2 bg-surfaceLight hover:bg-border text-white text-xs font-semibold rounded-xl transition-all"
          >
            Search
          </button>
        </div>

        {/* Users Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-border text-text-muted uppercase text-[10px] font-mono tracking-wider">
                <th className="pb-3 font-semibold">User Account</th>
                <th className="pb-3 font-semibold">Subscription Plan</th>
                <th className="pb-3 font-semibold">Devices</th>
                <th className="pb-3 font-semibold">Active VPN Tunnels</th>
                <th className="pb-3 font-semibold text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {users.map((u) => {
                const plan = u.subscription.planType;
                const isPro = plan === 'PRO' || plan === 'PREMIUM';
                const isFamily = plan === 'FAMILY';

                return (
                  <tr key={u.id} className="hover:bg-surfaceLight/50 transition-colors">
                    <td className="py-4">
                      <div className="font-semibold text-white">{u.email}</div>
                      <div className="text-[11px] text-text-muted flex items-center gap-1.5 mt-0.5">
                        <span className="font-mono text-[10px]">Role: {u.role}</span>
                        <span>&bull;</span>
                        <span>Joined {new Date(u.createdAt).toLocaleDateString()}</span>
                      </div>
                    </td>

                    <td className="py-4">
                      <span
                        className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[10px] font-bold font-mono ${
                          isFamily
                            ? 'bg-purple-500/15 text-purple-400 border border-purple-500/30'
                            : isPro
                            ? 'bg-primary/15 text-primary border border-primary/30'
                            : 'bg-surfaceLight text-text-muted border border-border'
                        }`}
                      >
                        <Sparkles className="w-3 h-3" />
                        {plan} ({u.subscription.maxDevices} Dev Max)
                      </span>
                    </td>

                    <td className="py-4">
                      <div className="flex items-center gap-1.5 text-text-muted">
                        <Smartphone className="w-3.5 h-3.5" />
                        <span className="font-mono font-medium text-white">{u.devicesCount}</span>
                        <span>registered</span>
                      </div>
                    </td>

                    <td className="py-4">
                      <span
                        className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold font-mono ${
                          u.activeSessionsCount > 0
                            ? 'bg-connectedGreen/15 text-connectedGreen border border-connectedGreen/30'
                            : 'bg-surfaceLight text-text-muted'
                        }`}
                      >
                        <span
                          className={`w-1.5 h-1.5 rounded-full ${
                            u.activeSessionsCount > 0 ? 'bg-connectedGreen' : 'bg-text-muted'
                          }`}
                        />
                        {u.activeSessionsCount} active
                      </span>
                    </td>

                    <td className="py-4 text-right space-x-2">
                      <button
                        onClick={() => handleOverridePlan(u.id, plan)}
                        className="px-2.5 py-1 text-[11px] font-semibold rounded-lg bg-surfaceLight hover:bg-border text-white border border-border transition-all"
                      >
                        Override Plan
                      </button>

                      {u.activeSessionsCount > 0 && (
                        <button
                          onClick={() => handleKillSessions(u.id, u.email)}
                          className="px-2.5 py-1 text-[11px] font-semibold rounded-lg bg-disconnectedRed/15 hover:bg-disconnectedRed/25 text-disconnectedRed border border-disconnectedRed/30 transition-all inline-flex items-center gap-1"
                        >
                          <Power className="w-3 h-3" />
                          Kill VPN
                        </button>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
