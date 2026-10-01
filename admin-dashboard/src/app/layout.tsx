import './globals.css';
import type { Metadata } from 'next';
import { Sidebar } from '../components/Sidebar';

export const metadata: Metadata = {
  title: 'Commercial VPN - Operator Admin Control Plane',
  description: 'Enterprise Edge Node Orchestration & Telemetry Dashboard',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="bg-background text-white flex min-h-screen">
        <Sidebar />
        <main className="flex-1 p-8 overflow-y-auto max-h-screen">
          {children}
        </main>
      </body>
    </html>
  );
}
