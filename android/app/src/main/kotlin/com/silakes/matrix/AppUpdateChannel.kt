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
                "canInstall" -> result.success(
                    Build.VERSION.SDK_INT < 26 || activity.packageManager.canRequestPackageInstalls(),
                )
                "openInstallSettings" -> {
                    if (Build.VERSION.SDK_INT >= 26) {
                        activity.startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:${activity.packageName}"),
                            ),
                        )
                    }
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

    fun dispose() = channel.setMethodCallHandler(null)
}
