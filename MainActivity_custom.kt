package com.raaz.gaming.gaming_tool

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import android.content.pm.PackageManager

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.raaz.gaming/shizuku"
    private var permissionResultChannel: MethodChannel.Result? = null

    // 🛠️ YAHAN NATIVE PERMISSION LISTENER HAI
    private val permissionListener = Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
        if (requestCode == 100) {
            val isGranted = grantResult == PackageManager.PERMISSION_GRANTED
            permissionResultChannel?.success(isGranted)
            permissionResultChannel = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Listener ko register karna
        Shizuku.addRequestPermissionResultListener(permissionListener)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // 1. Shizuku Service Check (Real Detection)
                "isShizukuServiceRunning" -> {
                    result.success(Shizuku.pingBinder())
                }
                
                // 2. Sirf Permission Check karna
                "checkPermission" -> {
                    try {
                        val isGranted = Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
                        result.success(isGranted)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                
                // 3. Permission Request karna (Native Popup)
                "requestPermission" -> {
                    try {
                        if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                            result.success(true)
                        } else {
                            // Flutter wait karega jab tak user Allow ya Deny na kare
                            permissionResultChannel = result
                            Shizuku.requestPermission(100)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Shizuku service not running", null)
                    }
                }
                
                // 4. Command chalana
                "executeCommand" -> {
                    val cmd = call.argument<String>("command")
                    if (cmd != null) {
                        try {
                            val process = Shizuku.newProcess(arrayOf("sh", "-c", cmd), null, null)
                            process.waitFor()
                            result.success(process.exitValue() == 0)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    } else {
                        result.error("ERROR", "Command empty", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // App band hone par listener hata do
        Shizuku.removeRequestPermissionResultListener(permissionListener)
    }
}
