package com.silakes.matrix

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat

/**
 * Setelah MATRIX diperbarui (APK baru terpasang di atas yang lama), buka lagi
 * aplikasinya dari awal. Android 10+ bisa menahan pembukaan dari latar, jadi
 * selalu disertai notifikasi "ketuk untuk membuka" (dihapus saat aplikasi terbuka).
 */
class UpdateRelaunchReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            ?: return

        runCatching { context.startActivity(launch) }

        val pending = PendingIntent.getActivity(
            context, 0, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(context, "mx_sistem")
            .setSmallIcon(R.drawable.ic_stat_matrix)
            .setContentTitle("MATRIX sudah diperbarui")
            .setContentText("Ketuk untuk membuka versi terbaru.")
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        runCatching {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .notify(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        const val NOTIFICATION_ID = 7301
    }
}
