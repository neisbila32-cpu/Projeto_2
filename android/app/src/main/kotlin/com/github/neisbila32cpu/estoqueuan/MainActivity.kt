package com.github.neisbila32cpu.estoqueuan

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "estoque_uan/app_info")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "versionName" -> result.success(installedVersion())
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION") // Compatível com o Android 7.0 (API 24).
    private fun installedVersion(): String? =
        packageManager.getPackageInfo(packageName, 0).versionName
}
