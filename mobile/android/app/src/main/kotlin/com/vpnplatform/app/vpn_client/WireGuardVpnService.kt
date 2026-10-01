package com.vpnplatform.app.vpn_client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import java.io.IOException

class WireGuardVpnService : VpnService() {

    companion object {
        const val ACTION_CONNECT = "com.vpnplatform.app.ACTION_CONNECT"
        const val ACTION_DISCONNECT = "com.vpnplatform.app.ACTION_DISCONNECT"
        const val CHANNEL_ID = "vpn_channel"
        const val NOTIFICATION_ID = 1001

        var isRunning: Boolean = false
            private set
    }

    private var vpnInterface: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val serverName = intent.getStringExtra("serverName") ?: "Secure Server"
                val clientIpV4 = intent.getStringExtra("clientAddressV4") ?: "10.8.0.2/24"
                val clientIpV6 = intent.getStringExtra("clientAddressV6") ?: "fd42:42:42::2/64"
                val dnsList = intent.getStringArrayListExtra("dns") ?: arrayListOf("10.8.0.1")
                val mtu = intent.getIntExtra("mtu", 1360)
                val killSwitch = intent.getBooleanExtra("killSwitch", false)
                val splitTunnelingEnabled = intent.getBooleanExtra("splitTunnelingEnabled", false)
                val splitTunnelingMode = intent.getStringExtra("splitTunnelingMode") ?: "bypass"
                val splitTunnelApps = intent.getStringArrayListExtra("splitTunnelingApps") ?: arrayListOf<String>()

                startVpnTunnel(
                    serverName,
                    clientIpV4,
                    clientIpV6,
                    dnsList,
                    mtu,
                    killSwitch,
                    splitTunnelingEnabled,
                    splitTunnelingMode,
                    splitTunnelApps
                )
            }
            ACTION_DISCONNECT -> {
                stopVpnTunnel()
            }
        }
        return START_NOT_STICKY
    }

    private fun startVpnTunnel(
        serverName: String,
        clientIpV4: String,
        clientIpV6: String,
        dnsList: ArrayList<String>,
        mtu: Int,
        killSwitch: Boolean,
        splitTunnelingEnabled: Boolean,
        splitTunnelingMode: String,
        splitTunnelApps: ArrayList<String>
    ) {
        try {
            createNotificationChannel()
            
            // Build notification subtitle reflecting security features
            var statusSubtitle = "Connected to $serverName • WireGuard"
            if (killSwitch) statusSubtitle += " • 🛡️ Kill Switch"
            if (splitTunnelingEnabled && splitTunnelApps.isNotEmpty()) {
                statusSubtitle += " • ⚡ Split (${splitTunnelApps.size} apps)"
            }
            startForeground(NOTIFICATION_ID, createNotification(statusSubtitle))

            val builder = Builder()
                .setSession(serverName)
                .setMtu(mtu)

            // 1. Kill Switch blocking mode (blocks unrouted traffic if tunnel drops)
            if (killSwitch) {
                builder.setBlocking(true)
            }

            // 2. Split Tunneling application rules
            if (splitTunnelingEnabled && splitTunnelApps.isNotEmpty()) {
                if (splitTunnelingMode == "only_vpn") {
                    // Only allowed applications route through VPN; all others use default internet
                    for (pkg in splitTunnelApps) {
                        try {
                            builder.addAllowedApplication(pkg)
                        } catch (_: Exception) {}
                    }
                } else {
                    // "bypass" mode: Disallowed applications bypass VPN completely
                    for (pkg in splitTunnelApps) {
                        try {
                            builder.addDisallowedApplication(pkg)
                        } catch (_: Exception) {}
                    }
                }
            }

            // Parse IPv4 address and prefix length
            val v4Parts = clientIpV4.split("/")
            val v4Addr = v4Parts[0]
            val v4Prefix = if (v4Parts.size > 1) v4Parts[1].toInt() else 24
            builder.addAddress(v4Addr, v4Prefix)

            // Add Default IPv4 Route (Route all traffic through tunnel)
            builder.addRoute("0.0.0.0", 0)

            // Parse IPv6 address if present
            try {
                val v6Parts = clientIpV6.split("/")
                val v6Addr = v6Parts[0]
                val v6Prefix = if (v6Parts.size > 1) v6Parts[1].toInt() else 64
                builder.addAddress(v6Addr, v6Prefix)
                builder.addRoute("::", 0)
            } catch (_: Exception) {}

            // Add DNS Resolvers
            for (dns in dnsList) {
                try {
                    builder.addDnsServer(dns)
                } catch (_: Exception) {}
            }

            // Establish TUN Interface
            vpnInterface?.close()
            vpnInterface = builder.establish()

            isRunning = true
            MainActivity.notifyTunnelState("connected")
        } catch (e: Exception) {
            e.printStackTrace()
            stopVpnTunnel()
            MainActivity.notifyTunnelState("error")
        }
    }

    private fun stopVpnTunnel() {
        isRunning = false
        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (e: IOException) {
            e.printStackTrace()
        }

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        MainActivity.notifyTunnelState("disconnected")
    }

    override fun onDestroy() {
        stopVpnTunnel()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN Connection Status",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows active WireGuard connection status"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(serverName: String): Notification {
        val launchIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Antigravity VPN: Protected")
            .setContentText("Connected to $serverName • WireGuard")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
