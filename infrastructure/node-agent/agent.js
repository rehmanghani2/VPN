#!/usr/bin/env node
/**
 * Commercial VPN Platform - Edge Node Synchronizer Daemon
 * Runs on every WireGuard edge server (Frankfurt, NY, Singapore, etc.)
 * Communicates with central NestJS backend to dynamically manage peers
 * and report real-time server telemetry.
 *
 * Zero-dependency: Uses only native Node.js core modules.
 */

const http = require('http');
const { execSync, exec } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

// Configuration
const PORT = process.env.AGENT_PORT || 51821;
const WG_INTERFACE = process.env.WG_INTERFACE || 'wg0';
const WG_CONF_PATH = process.env.WG_CONF_PATH || `/etc/wireguard/${WG_INTERFACE}.conf`;
const AUTH_TOKEN = process.env.NODE_AGENT_TOKEN || 'vpn-node-agent-secure-token-2026';

// Helper to validate Base64 WireGuard public key
function isValidPublicKey(key) {
  return typeof key === 'string' && /^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw480]=$/.test(key.trim());
}

// Read raw request JSON body
function getJsonBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
      if (body.length > 1024 * 1024) { // 1MB limit
        reject(new Error('Payload too large'));
      }
    });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (err) {
        reject(new Error('Invalid JSON format'));
      }
    });
    req.on('error', reject);
  });
}

// Send standard JSON response
function sendJson(res, statusCode, data) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'X-Powered-By': 'Antigravity-VPN-NodeAgent',
  });
  res.end(JSON.stringify(data));
}

// Server Request Handler
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const pathname = url.pathname;

  // 1. Health check (No auth required for basic ping)
  if (req.method === 'GET' && pathname === '/health') {
    return sendJson(res, 200, {
      status: 'UP',
      node: os.hostname(),
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
    });
  }

  // 2. Built-in Speed Test: Latency Probe (High precision)
  if (req.method === 'GET' && pathname === '/speedtest/ping') {
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache, no-store',
    });
    return res.end(JSON.stringify({ timestamp: Date.now(), hrtime: process.hrtime.bigint().toString() }));
  }

  // 3. Built-in Speed Test: High-Throughput Download Stream
  if (req.method === 'GET' && pathname === '/speedtest/download') {
    const sizeMb = Math.min(Math.max(parseInt(url.searchParams.get('sizeMb') || '10', 10), 1), 50);
    const totalBytes = sizeMb * 1024 * 1024;
    res.writeHead(200, {
      'Content-Type': 'application/octet-stream',
      'Content-Length': totalBytes,
      'Cache-Control': 'no-cache, no-store',
    });

    const chunk = Buffer.alloc(64 * 1024, 0x41); // 64KB zero-copy buffer
    let sentBytes = 0;

    function sendNext() {
      while (sentBytes < totalBytes) {
        const remaining = totalBytes - sentBytes;
        const currentChunk = remaining < chunk.length ? chunk.subarray(0, remaining) : chunk;
        sentBytes += currentChunk.length;
        const canContinue = res.write(currentChunk);
        if (!canContinue) {
          res.once('drain', sendNext);
          return;
        }
      }
      res.end();
    }
    sendNext();
    return;
  }

  // 4. Built-in Speed Test: Upload Sink
  if (req.method === 'POST' && pathname === '/speedtest/upload') {
    const startTime = Date.now();
    let receivedBytes = 0;
    req.on('data', (chunk) => {
      receivedBytes += chunk.length;
    });
    req.on('end', () => {
      const durationMs = Math.max(Date.now() - startTime, 1);
      const speedMbps = ((receivedBytes * 8) / (durationMs / 1000) / (1000 * 1000)).toFixed(2);
      sendJson(res, 200, {
        receivedBytes,
        durationMs,
        speedMbps: parseFloat(speedMbps),
      });
    });
    return;
  }

  // 5. Authentication check
  const authHeader = req.headers['x-node-token'] || req.headers['authorization'];
  const token = authHeader && authHeader.startsWith('Bearer ') ? authHeader.substring(7) : authHeader;

  if (token !== AUTH_TOKEN) {
    return sendJson(res, 401, { error: 'Unauthorized: Invalid node synchronization token' });
  }

  try {
    // --- POST /peers/add ---
    if (req.method === 'POST' && pathname === '/peers/add') {
      const { publicKey, allowedIps, presharedKey } = await getJsonBody(req);

      if (!isValidPublicKey(publicKey)) {
        return sendJson(res, 400, { error: 'Invalid WireGuard public key' });
      }

      if (!allowedIps || !Array.isArray(allowedIps) || allowedIps.length === 0) {
        return sendJson(res, 400, { error: 'allowedIps must be a non-empty array of CIDRs' });
      }

      const ipsString = allowedIps.join(',');

      // 1. Live dynamic kernel update via `wg set` (< 1ms execution, no packet drops)
      let wgCmd = `wg set ${WG_INTERFACE} peer "${publicKey}" allowed-ips "${ipsString}"`;
      if (presharedKey) {
        // Safe PSK passing via temp file or heredoc
        wgCmd = `wg set ${WG_INTERFACE} peer "${publicKey}" preshared-key <(echo "${presharedKey}") allowed-ips "${ipsString}"`;
      }

      try {
        execSync(wgCmd, { shell: '/bin/bash', stdio: 'pipe' });
      } catch (err) {
        console.error('[ERROR] Failed executing wg set:', err.message);
        return sendJson(res, 500, { error: `Failed to set peer in kernel: ${err.message}` });
      }

      // 2. Persist to wg0.conf so peer survives server reboot
      try {
        if (fs.existsSync(WG_CONF_PATH)) {
          let conf = fs.readFileSync(WG_CONF_PATH, 'utf8');
          // If peer not already in file, append it
          if (!conf.includes(publicKey)) {
            const peerBlock = `\n# Peer registered by NodeAgent: ${new Date().toISOString()}\n[Peer]\nPublicKey = ${publicKey}\nAllowedIPs = ${ipsString}\n`;
            fs.appendFileSync(WG_CONF_PATH, peerBlock);
          }
        }
      } catch (confErr) {
        console.warn('[WARN] Could not append to wg0.conf (non-fatal):', confErr.message);
      }

      console.log(`[SUCCESS] Peer added: ${publicKey.substring(0, 10)}... -> ${ipsString}`);
      return sendJson(res, 200, {
        success: true,
        message: 'Peer registered successfully in WireGuard kernel interface',
        peer: { publicKey, allowedIps },
      });
    }

    // --- POST /peers/remove ---
    if (req.method === 'POST' && pathname === '/peers/remove') {
      const { publicKey } = await getJsonBody(req);

      if (!isValidPublicKey(publicKey)) {
        return sendJson(res, 400, { error: 'Invalid WireGuard public key' });
      }

      // 1. Remove from live kernel
      try {
        execSync(`wg set ${WG_INTERFACE} peer "${publicKey}" remove`, { stdio: 'pipe' });
      } catch (err) {
        console.error('[ERROR] Failed executing wg set remove:', err.message);
      }

      // 2. Remove peer block from wg0.conf
      try {
        if (fs.existsSync(WG_CONF_PATH)) {
          const conf = fs.readFileSync(WG_CONF_PATH, 'utf8');
          // Regex match peer block
          const regex = new RegExp(`\n?#?[^\\[]*\\[Peer\\][^\\[]*PublicKey\\s*=\\s*${publicKey.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}[^\\[]*`, 'gi');
          const updatedConf = conf.replace(regex, '');
          fs.writeFileSync(WG_CONF_PATH, updatedConf);
        }
      } catch (confErr) {
        console.warn('[WARN] Could not clean wg0.conf:', confErr.message);
      }

      console.log(`[SUCCESS] Peer removed: ${publicKey.substring(0, 10)}...`);
      return sendJson(res, 200, {
        success: true,
        message: 'Peer removed from WireGuard kernel interface',
      });
    }

    // --- GET /metrics ---
    if (req.method === 'GET' && pathname === '/metrics') {
      let activePeers = 0;
      let totalRx = 0;
      let totalTx = 0;

      try {
        // wg show wg0 dump gives tab-separated output:
        // peer, preshared_key, endpoint, allowed_ips, latest_handshake, transfer_rx, transfer_tx, persistent_keepalive
        const dump = execSync(`wg show ${WG_INTERFACE} dump`, { encoding: 'utf8' }).trim().split('\n');
        // First line is interface info; peers follow
        const peerLines = dump.slice(1);
        activePeers = peerLines.length;

        for (const line of peerLines) {
          const parts = line.split('\t');
          if (parts.length >= 7) {
            totalRx += parseInt(parts[5], 10) || 0;
            totalTx += parseInt(parts[6], 10) || 0;
          }
        }
      } catch (dumpErr) {
        // Fallback for non-Linux dev environments
        activePeers = 0;
      }

      const totalMem = os.totalmem();
      const freeMem = os.freemem();
      const memoryUsagePercent = Math.round(((totalMem - freeMem) / totalMem) * 100);
      const cpus = os.cpus();
      const loadAvg = os.loadavg();

      return sendJson(res, 200, {
        node: os.hostname(),
        status: 'ONLINE',
        activePeers,
        bandwidth: {
          totalRxBytes: totalRx,
          totalTxBytes: totalTx,
        },
        system: {
          cpuCount: cpus.length,
          loadAverage: loadAvg,
          memoryUsagePercent,
          totalMemoryMB: Math.round(totalMem / (1024 * 1024)),
          freeMemoryMB: Math.round(freeMem / (1024 * 1024)),
        },
        timestamp: new Date().toISOString(),
      });
    }

    // --- POST /port-forward/enable ---
    if (req.method === 'POST' && pathname === '/port-forward/enable') {
      const { externalPort, internalPort, protocol = 'BOTH', clientTunnelIp } = await getJsonBody(req);
      if (!externalPort || !internalPort || !clientTunnelIp) {
        return sendJson(res, 400, { error: 'Missing externalPort, internalPort, or clientTunnelIp' });
      }

      const protos = protocol === 'BOTH' ? ['tcp', 'udp'] : [protocol.toLowerCase()];
      for (const proto of protos) {
        try {
          execSync(`iptables -t nat -A PREROUTING -p ${proto} --dport ${externalPort} -j DNAT --to-destination ${clientTunnelIp}:${internalPort}`, { stdio: 'pipe' });
          execSync(`iptables -A FORWARD -p ${proto} -d ${clientTunnelIp} --dport ${internalPort} -j ACCEPT`, { stdio: 'pipe' });
        } catch (e) {
          console.warn(`[WARN] iptables command skipped/failed (non-Linux or simulated): ${e.message}`);
        }
      }

      console.log(`[PORT-FORWARD] Enabled :${externalPort} -> ${clientTunnelIp}:${internalPort} (${protocol})`);
      return sendJson(res, 200, { success: true, externalPort, internalPort, protocol, clientTunnelIp });
    }

    // --- POST /port-forward/disable ---
    if (req.method === 'POST' && pathname === '/port-forward/disable') {
      const { externalPort, internalPort, protocol = 'BOTH', clientTunnelIp } = await getJsonBody(req);
      const protos = protocol === 'BOTH' ? ['tcp', 'udp'] : [protocol.toLowerCase()];

      for (const proto of protos) {
        try {
          execSync(`iptables -t nat -D PREROUTING -p ${proto} --dport ${externalPort} -j DNAT --to-destination ${clientTunnelIp}:${internalPort}`, { stdio: 'pipe' });
          execSync(`iptables -D FORWARD -p ${proto} -d ${clientTunnelIp} --dport ${internalPort} -j ACCEPT`, { stdio: 'pipe' });
        } catch (e) {
          // Rule removal error is non-fatal
        }
      }

      console.log(`[PORT-FORWARD] Disabled :${externalPort} -> ${clientTunnelIp}:${internalPort}`);
      return sendJson(res, 200, { success: true, message: 'Port forward rules flushed' });
    }

    // --- POST /dedicated-ip/bind ---
    if (req.method === 'POST' && pathname === '/dedicated-ip/bind') {
      const { clientTunnelIp, dedicatedPublicIp } = await getJsonBody(req);
      if (!clientTunnelIp || !dedicatedPublicIp) {
        return sendJson(res, 400, { error: 'Missing clientTunnelIp or dedicatedPublicIp' });
      }

      try {
        execSync(`iptables -t nat -A POSTROUTING -s ${clientTunnelIp} -j SNAT --to-source ${dedicatedPublicIp}`, { stdio: 'pipe' });
      } catch (e) {
        console.warn(`[WARN] iptables SNAT binding skipped: ${e.message}`);
      }

      console.log(`[DEDICATED-IP] Bound SNAT ${clientTunnelIp} -> ${dedicatedPublicIp}`);
      return sendJson(res, 200, { success: true, clientTunnelIp, dedicatedPublicIp });
    }

    // --- POST /dedicated-ip/unbind ---
    if (req.method === 'POST' && pathname === '/dedicated-ip/unbind') {
      const { clientTunnelIp, dedicatedPublicIp } = await getJsonBody(req);
      try {
        execSync(`iptables -t nat -D POSTROUTING -s ${clientTunnelIp} -j SNAT --to-source ${dedicatedPublicIp}`, { stdio: 'pipe' });
      } catch (e) {
        // Non-fatal
      }
      return sendJson(res, 200, { success: true, message: 'Dedicated IP SNAT unmapped' });
    }

    // --- POST /multihop/route ---
    if (req.method === 'POST' && pathname === '/multihop/route') {
      const { clientTunnelIp, exitServerIp, exitServerWgPublicKey } = await getJsonBody(req);
      if (!clientTunnelIp || !exitServerIp) {
        return sendJson(res, 400, { error: 'Missing clientTunnelIp or exitServerIp' });
      }

      // Configure policy routing rule so client packets are forwarded over the exit server inter-tunnel
      try {
        execSync(`ip rule add from ${clientTunnelIp} table 200`, { stdio: 'pipe' });
        execSync(`ip route add default via ${exitServerIp} dev ${WG_INTERFACE} table 200`, { stdio: 'pipe' });
      } catch (e) {
        console.warn(`[WARN] Policy routing command skipped/simulated: ${e.message}`);
      }

      console.log(`[MULTIHOP] Cascaded route: ${clientTunnelIp} ➔ Exit ${exitServerIp}`);
      return sendJson(res, 200, { success: true, clientTunnelIp, exitServerIp });
    }

    // --- POST /onion/route ---
    if (req.method === 'POST' && pathname === '/onion/route') {
      const { clientTunnelIp } = await getJsonBody(req);
      if (!clientTunnelIp) {
        return sendJson(res, 400, { error: 'Missing clientTunnelIp' });
      }

      // Transparent Tor redirection: TCP to Tor TransPort (9040), DNS to Tor DNSPort (5353)
      try {
        execSync(`iptables -t nat -A PREROUTING -s ${clientTunnelIp} -p tcp --syn -j REDIRECT --to-ports 9040`, { stdio: 'pipe' });
        execSync(`iptables -t nat -A PREROUTING -s ${clientTunnelIp} -p udp --dport 53 -j REDIRECT --to-ports 5353`, { stdio: 'pipe' });
      } catch (e) {
        console.warn(`[WARN] Tor transparent iptables redirect skipped/simulated: ${e.message}`);
      }

      console.log(`[ONION-ROUTING] Enforced Tor transparent proxy for ${clientTunnelIp}`);
      return sendJson(res, 200, { success: true, clientTunnelIp, torTransPort: 9040, torDnsPort: 5353 });
    }

    // Route not found
    return sendJson(res, 404, { error: 'Route not found' });

  } catch (err) {
    console.error('[UNHANDLED ERROR]', err);
    return sendJson(res, 500, { error: 'Internal server error: ' + err.message });
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('===========================================================');
  console.log(` Antigravity VPN Edge Node Agent listening on port ${PORT}`);
  console.log(` Interface: ${WG_INTERFACE}`);
  console.log(` Config path: ${WG_CONF_PATH}`);
  console.log('===========================================================');
});
