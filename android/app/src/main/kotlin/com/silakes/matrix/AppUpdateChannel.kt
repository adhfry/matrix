package com.silakes.matrix

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Pembaruan dalam aplikasi: izin "pasang aplikasi tidak dikenal" untuk MATRIX
 * dan membuka pemasang Android untuk APK yang sudah diunduh. Data aplikasi
 * (login, PIN, biometrik) tetap karena APK baru ditandatangani kunci yang sama.
 */
class AppUpdateChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "matrix/app_update")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" -> result.success(canInstall())
                "openInstallSettings" -> {
                    // Android 8+: izin per aplikasi. Android 7.x: sakelar global
                    // "Sumber tidak dikenal" di Pengaturan > Keamanan.
                    activity.startActivity(
                        if (Build.VERSION.SDK_INT >= 26) {
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:${activity.packageName}"),
                            )
                        } else {
                            Intent(Settings.ACTION_SECURITY_SETTINGS)
                        },
                    )
                    result.success(null)
                }
                "install" -> {
                    val file = File(call.argument<String>("path") ?: "")
                    if (!file.exists()) {
                        result.error("missing", "Berkas pembaruan tidak ditemukan.", null)
                        return@setMethodCallHandler
                    }
                    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
                    activity.startActivity(
                        Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canInstall(): Boolean =
        if (Build.VERSION.SDK_INT >= 26) {
            activity.packageManager.canRequestPackageInstalls()
        } else {
            @Suppress("DEPRECATION")
            Settings.Secure.getInt(activity.contentResolver, Settings.Secure.INSTALL_NON_MARKET_APPS, 0) == 1
        }

    fun dispose() = channel.setMethodCallHandler(null)
}
