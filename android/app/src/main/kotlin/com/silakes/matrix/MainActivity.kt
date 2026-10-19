package com.silakes.matrix

import android.app.NotificationManager
import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private var nfcTap: NfcTapChannel? = null
    private var appUpdate: AppUpdateChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Aplikasi sudah terbuka: notifikasi "MATRIX sudah diperbarui" tidak perlu lagi.
        runCatching {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .cancel(UpdateRelaunchReceiver.NOTIFICATION_ID)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        nfcTap = NfcTapChannel(this, messenger)
        appUpdate = AppUpdateChannel(this, messenger)
    }

    override fun onDestroy() {
        nfcTap?.dispose()
        appUpdate?.dispose()
        nfcTap = null
        appUpdate = null
        super.onDestroy()
    }
}
