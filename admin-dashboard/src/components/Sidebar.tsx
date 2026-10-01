'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  LayoutDashboard,
  Server,
  Users,
  BarChart3,
  ShieldCheck,
  Radio,
} from 'lucide-react';

const navItems = [
  { name: 'Cluster Overview', href: '/', icon: LayoutDashboard },
  { name: 'Edge Servers', href: '/servers', icon: Server },
  { name: 'User Management', href: '/users', icon: Users },
  { name: 'Global Telemetry', href: '/analytics', icon: BarChart3 },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="w-64 bg-surface border-r border-border min-h-screen flex flex-col p-4">
      {/* Brand Header */}
      <div className="flex items-center gap-3 px-3 py-4 mb-6">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-primary to-blue-600 flex items-center justify-center font-black text-black text-xl shadow-lg shadow-primary/20">
          <ShieldCheck className="w-6 h-6 text-black" />
        </div>
        <div>
          <h1 className="font-bold text-base tracking-tight text-white leading-none">ANTIGRAVITY</h1>
          <p className="text-[10px] font-mono tracking-widest text-primary font-bold mt-1">VPN CONTROL PLANE</p>
        </div>
      </div>

      {/* Navigation Links */}
      <nav className="space-y-1.5 flex-1">
        {navItems.map((item) => {
          const isActive = pathname === item.href;
          const Icon = item.icon;

          return (
            <Link
              key={item.name}
              href={item.href}
              className={`flex items-center gap-3 px-3.5 py-2.5 rounded-xl font-medium text-sm transition-all duration-150 ${
                isActive
                  ? 'bg-primary/10 text-primary border border-primary/25 shadow-sm shadow-primary/10 font-semibold'
                  : 'text-text-muted hover:bg-surfaceLight hover:text-white'
              }`}
            >
              <Icon className={`w-4 h-4 ${isActive ? 'text-primary' : 'text-text-muted'}`} />
              {item.name}
            </Link>
          );
        })}
      </nav>

      {/* Edge Node Daemon Liveness Badge */}
      <div className="p-3.5 rounded-xl bg-background border border-border mt-auto">
        <div className="flex items-center justify-between mb-1.5">
          <div className="flex items-center gap-2">
            <Radio className="w-3.5 h-3.5 text-connectedGreen animate-pulse" />
            <span className="text-xs font-semibold text-white">Cluster Mesh</span>
          </div>
          <span className="text-[10px] font-mono font-bold text-connectedGreen bg-connectedGreen/15 px-1.5 py-0.5 rounded">
            SYNCED
          </span>
        </div>
        <p className="text-[11px] text-text-muted font-mono">Control Plane v1.0.0 (NestJS)</p>
      </div>
    </aside>
  );
}
