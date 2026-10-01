'use client';

import React, { useEffect, useState } from 'react';
import { Header } from '../components/Header';
import { api } from '../lib/api';
import {
  Activity,
  Server,
  Users,
  HardDrive,
  Wifi,
  Shield,
  RefreshCw,
  PowerOff,
  CheckCircle,
  AlertTriangle,
} from 'lucide-react';

export default function DashboardPage() {
  const [overview, setOverview] = useState<any>(null);
  const [servers, setServers] = useState<any[]>([]);
  const [auditLogs, setAuditLogs] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const loadData = async () => {
    try {
      const [ovData, srvData, logData] = await Promise.all([
        api.getOverview().catch(() => null),
        api.getServers().catch(() => []),
        api.getAuditFeed().catch(() => []),
      ]);
      setOverview(ovData);
      setServers(srvData);
      setAuditLogs(logData);
    } catch (_) {
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
    const interval = setInterval(loadData, 5000);
    return () => clearInterval(interval);
  }, []);

  const handleDrain = async (id: string) => {
    try {
      await api.drainServer(id);
      loadData();
    } catch (e: any) {
      alert(e.message);
    }
  };

  const handleRestore = async (id: string) => {
    try {
      await api.restoreServer(id);
      loadData();
    } catch (e: any) {
      alert(e.message);
    }
  };

  return (
    <div>
      <Header
        title="Cluster Overview"
        subtitle="Global edge network telemetry and real-time infrastructure state"
      />

      {/* KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4 mb-8">
        <div className="bg-surface border border-border p-5 rounded-2xl relative overflow-hidden">
          <div className="flex items-center justify-between text-text-muted text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Active Tunnels</span>
            <Activity className="w-4 h-4 text-primary" />
          </div>
          <div className="text-3xl font-extrabold font-mono text-primary">
            {overview?.kpi?.activePeers ?? '--'}
          </div>
          <div className="text-[11px] text-text-muted mt-1">Simultaneous WireGuard sessions</div>
        </div>

        <div className="bg-surface border border-border p-5 rounded-2xl relative overflow-hidden">
          <div className="flex items-center justify-between text-text-muted text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Edge Nodes</span>
            <Server className="w-4 h-4 text-connectedGreen" />
          </div>
          <div className="text-3xl font-extrabold font-mono text-connectedGreen">
            {overview?.servers?.online ?? 0} / {overview?.servers?.total ?? 0}
          </div>
          <div className="text-[11px] text-text-muted mt-1">Nodes online worldwide</div>
        </div>

        <div className="bg-surface border border-border p-5 rounded-2xl relative overflow-hidden">
          <div className="flex items-center justify-between text-text-muted text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Total Users</span>
            <Users className="w-4 h-4 text-white" />
          </div>
          <div className="text-3xl font-extrabold font-mono text-white">
            {overview?.kpi?.totalUsers ?? '--'}
          </div>
          <div className="text-[11px] text-text-muted mt-1">Registered consumer accounts</div>
        </div>

        <div className="bg-surface border border-border p-5 rounded-2xl relative overflow-hidden">
          <div className="flex items-center justify-between text-text-muted text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Cluster Saturation</span>
            <HardDrive className="w-4 h-4 text-warningYellow" />
          </div>
          <div className="text-3xl font-extrabold font-mono text-warningYellow">
            {overview?.kpi?.clusterLoadPercent ?? 0}%
          </div>
          <div className="text-[11px] text-text-muted mt-1">Capacity: {overview?.kpi?.totalCapacity ?? 0} slots</div>
        </div>

        <div className="bg-surface border border-border p-5 rounded-2xl relative overflow-hidden">
          <div className="flex items-center justify-between text-text-muted text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Aggregated Bandwidth</span>
            <Wifi className="w-4 h-4 text-primary" />
          </div>
          <div className="text-3xl font-extrabold font-mono text-primary">
            {overview?.kpi?.estimatedBandwidthGbps ?? 0} <span className="text-sm font-normal">Gbps</span>
          </div>
          <div className="text-[11px] text-text-muted mt-1">Estimated global data transit</div>
        </div>
      </div>

      {/* Main Grid: Server Topology & Live Audit Logs */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Server Nodes Table */}
        <div className="lg:col-span-2 bg-surface border border-border rounded-2xl p-6">
          <div className="flex items-center justify-between mb-5">
            <div>
              <h3 className="text-base font-bold text-white">Cluster Edge Nodes</h3>
              <p className="text-xs text-text-muted">Distributed high-speed Linux WireGuard gateways</p>
            </div>
            <button
              onClick={loadData}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-surfaceLight hover:bg-border text-xs text-text-muted hover:text-white transition-all"
            >
              <RefreshCw className="w-3.5 h-3.5" />
              <span>Refresh</span>
            </button>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b border-border text-text-muted uppercase text-[10px] font-mono tracking-wider">
                  <th className="pb-3 font-semibold">Node / Location</th>
                  <th className="pb-3 font-semibold">Endpoint</th>
                  <th className="pb-3 font-semibold">Status</th>
                  <th className="pb-3 font-semibold">Load / Capacity</th>
                  <th className="pb-3 font-semibold text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {servers.map((srv) => {
                  const isOnline = srv.status === 'ONLINE';
                  const isDraining = srv.status === 'DRAINING';

                  return (
                    <tr key={srv.id} className="hover:bg-surfaceLight/50 transition-colors">
                      <td className="py-3.5">
                        <div className="font-semibold text-white flex items-center gap-2">
                          <span>{srv.name}</span>
                          {srv.isObfuscated && (
                            <span className="text-[9px] font-bold bg-primary/15 text-primary border border-primary/30 px-1.5 py-0.5 rounded font-mono">
                              STEALTH 443
                            </span>
                          )}
                        </div>
                        <div className="text-[11px] text-text-muted">
                          {srv.city}, {srv.countryName} ({srv.countryCode})
                        </div>
                      </td>

                      <td className="py-3.5 font-mono text-[11px] text-text-muted">
                        {srv.publicIp}:{srv.isObfuscated ? srv.obfuscationPort : srv.wgPort}
                      </td>

                      <td className="py-3.5">
                        <span
                          className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold font-mono ${
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
                          {srv.status}
                        </span>
                      </td>

                      <td className="py-3.5">
                        <div className="flex items-center justify-between font-mono text-[11px] mb-1">
                          <span>{srv.currentLoad} / {srv.capacity}</span>
                          <span className="text-text-muted">{srv.loadPercent}%</span>
                        </div>
                        <div className="w-28 h-1.5 bg-background rounded-full overflow-hidden">
                          <div
                            className="h-full bg-primary rounded-full transition-all"
                            style={{ width: `${Math.min(srv.loadPercent, 100)}%` }}
                          />
                        </div>
                      </td>

                      <td className="py-3.5 text-right">
                        {isOnline ? (
                          <button
                            onClick={() => handleDrain(srv.id)}
                            className="px-2.5 py-1 text-[11px] font-semibold rounded-lg bg-warningYellow/15 hover:bg-warningYellow/25 text-warningYellow border border-warningYellow/30 transition-all"
                          >
                            Drain Node
                          </button>
                        ) : (
                          <button
                            onClick={() => handleRestore(srv.id)}
                            className="px-2.5 py-1 text-[11px] font-semibold rounded-lg bg-connectedGreen/15 hover:bg-connectedGreen/25 text-connectedGreen border border-connectedGreen/30 transition-all"
                          >
                            Make Online
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

        {/* Live Event Stream */}
        <div className="bg-surface border border-border rounded-2xl p-6 flex flex-col">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-base font-bold text-white">Live Cluster Stream</h3>
              <p className="text-xs text-text-muted">Real-time peer handshakes & connections</p>
            </div>
            <span className="text-[10px] font-mono font-bold text-connectedGreen bg-connectedGreen/15 px-2 py-0.5 rounded-full border border-connectedGreen/30 animate-pulse">
              LIVE 5s
            </span>
          </div>

          <div className="space-y-3 flex-1 overflow-y-auto max-h-[460px] pr-1">
            {auditLogs.length === 0 ? (
              <p className="text-xs text-text-muted text-center py-8">Waiting for connection events...</p>
            ) : (
              auditLogs.map((log) => {
                const isConnect = log.event === 'PEER_CONNECTED';
                return (
                  <div
                    key={log.id}
                    className="p-3 rounded-xl bg-background border border-border flex items-start justify-between gap-3 text-xs"
                  >
                    <div>
                      <div className="flex items-center gap-1.5 font-semibold text-white">
                        <span
                          className={`w-1.5 h-1.5 rounded-full ${
                            isConnect ? 'bg-connectedGreen' : 'bg-disconnectedRed'
                          }`}
                        />
                        <span>{log.device}</span>
                      </div>
                      <div className="text-[11px] text-text-muted mt-0.5">
                        {log.server} &bull; <span className="font-mono text-primary">{log.allocatedIp}</span>
                      </div>
                    </div>
                    <span className="text-[10px] font-mono text-text-muted shrink-0">
                      {new Date(log.timestamp).toLocaleTimeString()}
                    </span>
                  </div>
                );
              })
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
