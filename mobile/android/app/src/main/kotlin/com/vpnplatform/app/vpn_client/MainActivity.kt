package com.vpnplatform.app.vpn_client

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.vpnplatform.app/vpn"
        private const val VPN_REQUEST_CODE = 0x0F24

        private var methodChannel: MethodChannel? = null

        fun notifyTunnelState(state: String) {
            methodChannel?.invokeMethod("onTunnelStateChanged", mapOf("state" to state))
        }
    }

    private var pendingConnectArgs: Map<String, Any>? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startTunnel" -> {
                    val args = call.arguments as? Map<String, Any>
                    if (args == null) {
                        result.error("INVALID_ARGS", "Missing tunnel configuration", null)
                        return@setMethodCallHandler
                    }

                    val vpnIntent = VpnService.prepare(this)
                    if (vpnIntent != null) {
                        // User has not yet granted Android VPN permission
                        pendingConnectArgs = args
                        pendingResult = result
                        startActivityForResult(vpnIntent, VPN_REQUEST_CODE)
                    } else {
                        // Permission already granted
                        launchVpnService(args)
                        result.success(true)
                    }
                }
                "stopTunnel" -> {
                    val stopIntent = Intent(this, WireGuardVpnService::class.java).apply {
                        action = WireGuardVpnService.ACTION_DISCONNECT
                    }
                    startService(stopIntent)
                    result.success(true)
                }
                "getTunnelState" -> {
                    val state = if (WireGuardVpnService.isRunning) "connected" else "disconnected"
                    result.success(state)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun launchVpnService(args: Map<String, Any>) {
        val intent = Intent(this, WireGuardVpnService::class.java).apply {
            action = WireGuardVpnService.ACTION_CONNECT
            putExtra("serverName", args["serverName"] as? String ?: "VPN Server")
            putExtra("clientAddressV4", args["clientAddressV4"] as? String ?: "10.8.0.2/24")
            putExtra("clientAddressV6", args["clientAddressV6"] as? String ?: "fd42:42:42::2/64")
            putExtra("mtu", args["mtu"] as? Int ?: 1360)

            val dnsRaw = args["dns"] as? List<*>
            val dnsList = ArrayList<String>()
            dnsRaw?.forEach { if (it is String) dnsList.add(it) }
            putStringArrayListExtra("dns", dnsList)
        }
        startService(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                val args = pendingConnectArgs
                if (args != null) {
                    launchVpnService(args)
                    pendingResult?.success(true)
                } else {
                    pendingResult?.error("STATE_ERROR", "Pending args lost", null)
                }
            } else {
                pendingResult?.error("PERMISSION_DENIED", "User denied VPN permission", null)
                notifyTunnelState("disconnected")
            }
            pendingConnectArgs = null
            pendingResult = null
        }
    }

    override fun onDestroy() {
        methodChannel = null
        super.onDestroy()
    }
}
