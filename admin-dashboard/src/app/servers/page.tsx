'use client';

import React, { useEffect, useState } from 'react';
import { Header } from '../../components/Header';
import { api } from '../../lib/api';
import { Server, Shield, Globe, HardDrive, RefreshCw } from 'lucide-react';

export default function ServersPage() {
  const [servers, setServers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const loadServers = async () => {
    setLoading(true);
    try {
      const data = await api.getServers();
      setServers(data);
    } catch (_) {
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadServers();
  }, []);

  const handleDrain = async (id: string) => {
    await api.drainServer(id);
    loadServers();
  };

  const handleRestore = async (id: string) => {
    await api.restoreServer(id);
    loadServers();
  };

  return (
    <div>
      <Header
        title="Cluster Server Nodes"
        subtitle="Manage distributed WireGuard data-plane gateways across global cloud regions"
      />

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {servers.map((s) => {
          const isOnline = s.status === 'ONLINE';
          const isDraining = s.status === 'DRAINING';

          return (
            <div
              key={s.id}
              className="bg-surface border border-border rounded-2xl p-6 relative overflow-hidden flex flex-col justify-between"
            >
              <div>
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-2.5">
                    <div className="w-9 h-9 rounded-xl bg-surfaceLight flex items-center justify-center text-primary">
                      <Server className="w-5 h-5" />
                    </div>
                    <div>
                      <h3 className="font-bold text-base text-white">{s.name}</h3>
                      <p className="text-xs text-text-muted flex items-center gap-1">
                        <Globe className="w-3 h-3" />
                        {s.city}, {s.countryName} ({s.countryCode})
                      </p>
                    </div>
                  </div>

                  <span
                    className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-bold font-mono ${
                      isOnline
                        ? 'bg-connectedGreen/15 text-connectedGreen border border-connectedGreen/30'
                        : isDraining
                        ? 'bg-warningYellow/15 text-warningYellow border border-warningYellow/30'
                        : 'bg-disconnectedRed/15 text-disconnectedRed border border-disconnectedRed/30'
                    }`}
                  >
                    <span
                      className={`w-1.5 h-1.5 rounded-full ${
                        isOnline
                          ? 'bg-connectedGreen'
                          : isDraining
                          ? 'bg-warningYellow'
                          : 'bg-disconnectedRed'
                      }`}
                    />
                    {s.status}
                  </span>
                </div>

                {/* Specs */}
                <div className="space-y-2 p-3.5 rounded-xl bg-background border border-border text-xs mb-5 font-mono">
                  <div className="flex justify-between">
                    <span className="text-text-muted">Public IP</span>
                    <span className="text-white">{s.publicIp}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-text-muted">WireGuard Port</span>
                    <span className="text-white">{s.wgPort} UDP</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-text-muted">Obfuscation</span>
                    <span className={s.isObfuscated ? 'text-primary font-bold' : 'text-text-muted'}>
                      {s.isObfuscated ? `${s.obfuscationProtocol} (Port ${s.obfuscationPort})` : 'None (Standard)'}
                    </span>
                  </div>
                </div>

                {/* Load Bar */}
                <div className="mb-5">
                  <div className="flex justify-between text-xs font-mono mb-1.5">
                    <span className="text-text-muted">Peer Saturation</span>
                    <span className="text-white font-bold">{s.currentLoad} / {s.capacity} ({s.loadPercent}%)</span>
                  </div>
                  <div className="h-2 bg-background rounded-full overflow-hidden">
                    <div
                      className={`h-full rounded-full transition-all ${
                        s.loadPercent > 80 ? 'bg-disconnectedRed' : s.loadPercent > 50 ? 'bg-warningYellow' : 'bg-primary'
                      }`}
                      style={{ width: `${Math.min(s.loadPercent, 100)}%` }}
                    />
                  </div>
                </div>
              </div>

              {/* Actions */}
              <div className="pt-4 border-t border-border flex items-center justify-between">
                <span className="text-[11px] text-text-muted">Failover auto-managed</span>
                {isOnline ? (
                  <button
                    onClick={() => handleDrain(s.id)}
                    className="px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-warningYellow/15 hover:bg-warningYellow/25 text-warningYellow border border-warningYellow/30 transition-all"
                  >
                    Drain Server
                  </button>
                ) : (
                  <button
                    onClick={() => handleRestore(s.id)}
                    className="px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-connectedGreen/15 hover:bg-connectedGreen/25 text-connectedGreen border border-connectedGreen/30 transition-all"
                  >
                    Restore Online
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
