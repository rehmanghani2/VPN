'use client';

import React, { useEffect, useState } from 'react';
import { Header } from '../../components/Header';
import { api } from '../../lib/api';
import { BarChart3, Globe2, ShieldCheck, Zap } from 'lucide-react';

export default function AnalyticsPage() {
  const [overview, setOverview] = useState<any>(null);
  const [servers, setServers] = useState<any[]>([]);

  useEffect(() => {
    Promise.all([
      api.getOverview().catch(() => null),
      api.getServers().catch(() => []),
    ]).then(([ov, srvs]) => {
      setOverview(ov);
      setServers(srvs);
    });
  }, []);

  return (
    <div>
      <Header
        title="Global Telemetry & Analytics"
        subtitle="Network bandwidth distribution, regional saturation, and commercial growth metrics"
      />

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
        {/* Subscription Tier Distribution */}
        <div className="bg-surface border border-border rounded-2xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <ShieldCheck className="w-5 h-5 text-primary" />
            <h3 className="font-bold text-base text-white">Subscription Tier Breakdown</h3>
          </div>
          <p className="text-xs text-text-muted mb-5">Active customer distribution across commercial tiers</p>

          <div className="space-y-4">
            {overview?.subscriptions?.breakdown &&
              Object.entries(overview.subscriptions.breakdown).map(([tier, count]: [string, any]) => {
                const total = overview.subscriptions.total || 1;
                const percent = Math.round((count / total) * 100);

                return (
                  <div key={tier}>
                    <div className="flex justify-between text-xs font-mono mb-1">
                      <span className="font-bold text-white">{tier} PLAN</span>
                      <span className="text-text-muted">{count} users ({percent}%)</span>
                    </div>
                    <div className="h-2 bg-background rounded-full overflow-hidden">
                      <div
                        className="h-full bg-gradient-to-r from-primary to-blue-500 rounded-full"
                        style={{ width: `${percent}%` }}
                      />
                    </div>
                  </div>
                );
              })}
          </div>
        </div>

        {/* Regional Network Capacity */}
        <div className="bg-surface border border-border rounded-2xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <Globe2 className="w-5 h-5 text-connectedGreen" />
            <h3 className="font-bold text-base text-white">Regional Traffic Distribution</h3>
          </div>
          <p className="text-xs text-text-muted mb-5">Active WireGuard tunnels across global edge gateways</p>

          <div className="space-y-4">
            {servers.map((s) => (
              <div key={s.id}>
                <div className="flex justify-between text-xs font-mono mb-1">
                  <span className="text-white font-medium">{s.city}, {s.countryName}</span>
                  <span className="text-primary font-bold">{s.currentLoad} peers</span>
                </div>
                <div className="h-2 bg-background rounded-full overflow-hidden">
                  <div
                    className="h-full bg-connectedGreen rounded-full"
                    style={{ width: `${Math.min(s.loadPercent, 100)}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
