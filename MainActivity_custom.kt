package com.raaz.gaming.gaming_tool // 🛠️ YAHAN FIX HAI: Sahi package name

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import android.content.pm.PackageManager

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.raaz.gaming/shizuku"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    try {
                        val isGranted = Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
                        result.success(isGranted)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "requestPermission" -> {
                    try {
                        Shizuku.requestPermission(0)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Shizuku not running", null)
                    }
                }
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
}
