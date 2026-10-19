package com.silakes.matrix

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Jembatan Flutter <-> NFC: cek dukungan, baca UID kartu, pasang/lepas tap HP. */
class NfcTapChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "matrix/nfc_tap")
    private val main = Handler(Looper.getMainLooper())
    private var pendingRead: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(status())
                "openNfcSettings" -> {
                    activity.startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
                    result.success(null)
                }
                "readCardUid" -> readCardUid(result)
                "cancelRead" -> {
                    stopReader()
                    pendingRead?.success(null)
                    pendingRead = null
                    result.success(null)
                }
                "install" -> {
                    val secret = Base64.decode(call.argument<String>("secret"), Base64.DEFAULT)
                    NfcTapStore.install(activity, secret, call.argument<String>("tapId") ?: "")
                    result.success(status())
                }
                "setEnabled" -> {
                    NfcTapStore.setEnabled(activity, call.argument<Boolean>("enabled") == true)
                    result.success(status())
                }
                "remove" -> {
                    NfcTapStore.remove(activity)
                    result.success(status())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun status(): Map<String, Any?> {
        val pm = activity.packageManager
        val adapter = NfcAdapter.getDefaultAdapter(activity)
        return mapOf(
            "nfc" to (adapter != null && pm.hasSystemFeature(PackageManager.FEATURE_NFC)),
            "hce" to pm.hasSystemFeature(PackageManager.FEATURE_NFC_HOST_CARD_EMULATION),
            "nfcOn" to (adapter?.isEnabled == true),
            // Android 14+: tap boleh saat layar mati (bila perangkat mengizinkan).
            "screenOff" to (Build.VERSION.SDK_INT >= 34),
            "installed" to NfcTapStore.isInstalled(activity),
            "enabled" to NfcTapStore.isEnabled(activity),
            "deviceUuid" to NfcTapStore.deviceUuid(activity),
            "deviceModel" to "${Build.MANUFACTURER.replaceFirstChar { it.uppercase() }} ${Build.MODEL}",
        )
    }

    /** Mode pembaca: tunggu satu kartu, kembalikan UID hex (huruf besar). */
    private fun readCardUid(result: MethodChannel.Result) {
        val adapter = NfcAdapter.getDefaultAdapter(activity)
        if (adapter == null || !adapter.isEnabled) {
            result.error("nfc_off", "NFC belum aktif.", null)
            return
        }
        pendingRead?.success(null)
        pendingRead = result
        val flags = NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or NfcAdapter.FLAG_READER_NFC_V or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK
        adapter.enableReaderMode(activity, { tag ->
            val uid = tag.id.joinToString("") { "%02X".format(it) }
            main.post {
                stopReader()
                pendingRead?.success(uid)
                pendingRead = null
            }
        }, flags, null)
    }

    private fun stopReader() {
        runCatching { NfcAdapter.getDefaultAdapter(activity)?.disableReaderMode(activity) }
    }

    fun dispose() {
        stopReader()
        channel.setMethodCallHandler(null)
    }
}
