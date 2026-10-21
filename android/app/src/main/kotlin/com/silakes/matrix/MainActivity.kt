package com.silakes.matrix

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
        // Layar panggilan tampil di atas layar kunci hanya selama ada panggilan,
        // bukan permanen (isi aplikasi lain tidak boleh terlihat tanpa membuka kunci).
        MethodChannel(messenger, "matrix/call_window").setMethodCallHandler { call, result ->
            if (call.method == "setOverLockScreen") {
                setOverLockScreen(call.arguments as? Boolean ?: false)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun setOverLockScreen(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    override fun onDestroy() {
        nfcTap?.dispose()
        appUpdate?.dispose()
        nfcTap = null
        appUpdate = null
        super.onDestroy()
    }
}
