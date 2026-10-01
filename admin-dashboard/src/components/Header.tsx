'use client';

import React, { useState, useEffect } from 'react';
import { api, getStoredToken, setStoredToken } from '../lib/api';
import { Shield, Key, RefreshCw, CheckCircle2 } from 'lucide-react';

export function Header({ title, subtitle }: { title: string; subtitle?: string }) {
  const [token, setToken] = useState('');
  const [isAuthed, setIsAuthed] = useState(false);
  const [isLoggingIn, setIsLoggingIn] = useState(false);

  useEffect(() => {
    const existing = getStoredToken();
    if (existing) {
      setToken(existing);
      setIsAuthed(true);
    }
  }, []);

  const handleAutoLogin = async () => {
    setIsLoggingIn(true);
    try {
      const res = await api.loginAdmin();
      setToken(res.accessToken);
      setIsAuthed(true);
      window.location.reload();
    } catch (err: any) {
      alert('Login failed: ' + err.message);
    } finally {
      setIsLoggingIn(false);
    }
  };

  const handleManualToken = () => {
    if (token) {
      setStoredToken(token.trim());
      setIsAuthed(true);
      window.location.reload();
    }
  };

  return (
    <header className="flex flex-col md:flex-row md:items-center justify-between pb-6 mb-6 border-b border-border gap-4">
      <div>
        <h2 className="text-2xl font-bold text-white tracking-tight">{title}</h2>
        {subtitle && <p className="text-sm text-text-muted mt-0.5">{subtitle}</p>}
      </div>

      <div className="flex items-center gap-3">
        {isAuthed ? (
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-connectedGreen/10 border border-connectedGreen/30 text-connectedGreen text-xs font-semibold">
            <CheckCircle2 className="w-4 h-4" />
            <span>Admin Authenticated</span>
          </div>
        ) : (
          <div className="flex items-center gap-2">
            <input
              type="password"
              placeholder="Paste Admin JWT Token..."
              value={token}
              onChange={(e) => setToken(e.target.value)}
              className="bg-surfaceLight border border-border px-3 py-1.5 text-xs rounded-lg text-white w-48 focus:border-primary outline-none"
            />
            <button
              onClick={handleManualToken}
              className="px-3 py-1.5 rounded-lg bg-surfaceLight hover:bg-border text-xs text-white border border-border"
            >
              Auth
            </button>
          </div>
        )}

        <button
          onClick={handleAutoLogin}
          disabled={isLoggingIn}
          className="flex items-center gap-2 px-3.5 py-1.5 rounded-xl bg-primary hover:bg-primary/90 text-black font-bold text-xs shadow-md shadow-primary/15 transition-all"
        >
          {isLoggingIn ? (
            <RefreshCw className="w-3.5 h-3.5 animate-spin" />
          ) : (
            <Key className="w-3.5 h-3.5" />
          )}
          <span>Quick Admin Login</span>
        </button>
      </div>
    </header>
  );
}
