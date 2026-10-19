package com.silakes.matrix

import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.security.keystore.KeyProperties
import android.security.keystore.KeyProtection
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Kunci & status "HP sebagai alat tap". Kunci HMAC diimpor ke Android Keystore
 * (tidak bisa disalin keluar); counter & ID perangkat di penyimpanan
 * device-protected agar layanan tap tetap bisa menjawab saat HP terkunci.
 */
object NfcTapStore {
    private const val ALIAS = "matrix_nfc_tap"
    private const val PREFS = "matrix_nfc_tap"
    private const val KEY_UUID = "device_uuid"
    private const val KEY_TAP_ID = "tap_id"
    private const val KEY_COUNTER = "counter"
    private const val KEY_INSTALLED = "installed"
    private const val KEY_ENABLED = "enabled"

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.createDeviceProtectedStorageContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun keyStore(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    /** ID perangkat tetap untuk instalasi ini (dibuat sekali). */
    fun deviceUuid(ctx: Context): String {
        val p = prefs(ctx)
        return p.getString(KEY_UUID, null) ?: UUID.randomUUID().toString().also {
            p.edit().putString(KEY_UUID, it).commit()
        }
    }

    fun isInstalled(ctx: Context): Boolean =
        prefs(ctx).getBoolean(KEY_INSTALLED, false) && keyStore().containsAlias(ALIAS)

    fun isEnabled(ctx: Context): Boolean = isInstalled(ctx) && prefs(ctx).getBoolean(KEY_ENABLED, false)

    /** Simpan kunci & ID tap dari server (sekali), counter mulai 0, layanan tap aktif. */
    fun install(ctx: Context, secret: ByteArray, tapId: String) {
        keyStore().setEntry(
            ALIAS,
            KeyStore.SecretKeyEntry(SecretKeySpec(secret, "HmacSHA256")),
            KeyProtection.Builder(KeyProperties.PURPOSE_SIGN).build(),
        )
        secret.fill(0)
        prefs(ctx).edit().putLong(KEY_COUNTER, 0).putString(KEY_TAP_ID, tapId)
            .putBoolean(KEY_INSTALLED, true).commit()
        setEnabled(ctx, true)
    }

    fun setEnabled(ctx: Context, enabled: Boolean) {
        prefs(ctx).edit().putBoolean(KEY_ENABLED, enabled).commit()
        ctx.packageManager.setComponentEnabledSetting(
            ComponentName(ctx, MatrixTapService::class.java),
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }

    fun remove(ctx: Context) {
        setEnabled(ctx, false)
        runCatching { keyStore().deleteEntry(ALIAS) }
        prefs(ctx).edit().remove(KEY_COUNTER).remove(KEY_TAP_ID).putBoolean(KEY_INSTALLED, false).commit()
    }

    /**
     * Token sekali pakai "MX1.<tap_id>.<counter>.<hmac 12 byte>" (<= 64 byte,
     * muat satu bingkai RC522): counter dinaikkan & disimpan dulu, baru
     * ditandatangani (tidak ada counter yang terpakai dua kali).
     */
    @Synchronized
    fun nextToken(ctx: Context): String? {
        if (!isEnabled(ctx)) return null
        val p = prefs(ctx)
        val counter = p.getLong(KEY_COUNTER, 0) + 1
        if (!p.edit().putLong(KEY_COUNTER, counter).commit()) return null

        val tapId = p.getString(KEY_TAP_ID, null) ?: return null
        val payload = "MX1.$tapId.$counter"
        val mac = Mac.getInstance("HmacSHA256").apply { init(keyStore().getKey(ALIAS, null)) }
        val sig = mac.doFinal(payload.toByteArray(Charsets.US_ASCII))
        return payload + "." + sig.take(12).joinToString("") { "%02x".format(it) }
    }
}
