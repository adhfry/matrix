package com.silakes.matrix

import android.content.Context
import android.nfc.cardemulation.HostApduService
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * HP sebagai kartu absen (HCE). Alat RC522 mengirim SELECT AID MATRIX
 * (F0 4D 41 54 52 49 58 01 = F0 "MATRIX" 01); layanan menjawab token
 * sekali pakai dari [NfcTapStore] + status 90 00. Berjalan tanpa membuka
 * aplikasi; tidak butuh internet di HP (server yang memverifikasi).
 */
class MatrixTapService : HostApduService() {

    override fun processCommandApdu(apdu: ByteArray, extras: Bundle?): ByteArray {
        if (!isSelectMatrix(apdu)) return SW_NOT_FOUND
        val token = runCatching { NfcTapStore.nextToken(this) }.getOrNull() ?: return SW_NOT_FOUND
        buzz()
        return token.toByteArray(Charsets.US_ASCII) + SW_OK
    }

    override fun onDeactivated(reason: Int) = Unit

    private fun isSelectMatrix(apdu: ByteArray): Boolean {
        if (apdu.size < 5 + AID.size) return false
        if (apdu[1] != 0xA4.toByte() || apdu[2] != 0x04.toByte()) return false
        val len = apdu[4].toInt() and 0xFF
        return len == AID.size && apdu.copyOfRange(5, 5 + len).contentEquals(AID)
    }

    /** Getar singkat: tanda HP sudah menjawab alat. */
    private fun buzz() {
        runCatching {
            val vib = if (Build.VERSION.SDK_INT >= 31) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (Build.VERSION.SDK_INT >= 26) {
                vib.vibrate(VibrationEffect.createOneShot(60, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vib.vibrate(60)
            }
        }
    }

    companion object {
        val AID = byteArrayOf(0xF0.toByte(), 0x4D, 0x41, 0x54, 0x52, 0x49, 0x58, 0x01)
        private val SW_OK = byteArrayOf(0x90.toByte(), 0x00)
        private val SW_NOT_FOUND = byteArrayOf(0x6A, 0x82.toByte())
    }
}
