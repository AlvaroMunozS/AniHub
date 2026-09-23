package com.alvaromunozs.anihub

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val installer = ApkInstaller(this)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        installer.register()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "anihub/installer")
            .setMethodCallHandler(installer)
    }

    override fun onResume() {
        super.onResume()
        installer.onResume()
    }

    override fun onPause() {
        installer.onPause()
        super.onPause()
    }

    override fun onDestroy() {
        installer.unregister()
        super.onDestroy()
    }
}
