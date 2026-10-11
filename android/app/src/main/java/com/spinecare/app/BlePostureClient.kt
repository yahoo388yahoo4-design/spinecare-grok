package com.spinecare.app

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.util.Log
import java.util.UUID

/** BLE client for the ESP32 posture nodes (see firmware/).
 *  Service 128-bit: 16-bit UUIDs 0xFFF0 (service), 0xFFF1 (head IMU), 0xFFF2 (trunk IMU),
 *  0xFFF3 (control). Payload: 24 bytes little-endian:
 *  [0..1] seq, [2..3] pitch*100 int16, [4..5] roll*100, [6..7] yaw*100,
 *  [8..9] acc_x mg, [10..11] acc_y, [12..13] acc_z, [14..15] gyr_x dps*10, ...
 *  [16..23] same for second sensor when combined mode. */
class BlePostureClient(private val context: Context) {
    companion object {
        private const val TAG = "BlePosture"
        val SERVICE: UUID = UUID.fromString("0000fff0-0000-1000-8000-00805f9b34fb")
        val CHR_HEAD: UUID = UUID.fromString("0000fff1-0000-1000-8000-00805f9b34fb")
        val CHR_TRUNK: UUID = UUID.fromString("0000fff2-0000-1000-8000-00805f9b34fb")
    }

    data class ImuPacket(val seq: Int, val pitch: Double, val roll: Double, val yaw: Double,
                         val ax: Int, val ay: Int, val az: Int, val gx: Int, val gy: Int, val gz: Int)

    interface Listener {
        fun onHead(p: ImuPacket)
        fun onTrunk(p: ImuPacket)
        fun onConnected(connected: Boolean)
    }
    private var listener: Listener? = null
    private var gatt: BluetoothGatt? = null
    var connected = false; private set

    @SuppressLint("MissingPermission")
    fun connect(device: BluetoothDevice, listener: Listener) {
        this.listener = listener
        gatt = device.connectGatt(context, false, object : BluetoothGattCallback() {
            override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    connected = true; listener.onConnected(true)
                    g.discoverServices()
                } else { connected = false; listener.onConnected(false) }
            }
            override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
                g.getService(SERVICE)?.let { svc ->
                    listOf(CHR_HEAD, CHR_TRUNK).forEach { uid ->
                        svc.getCharacteristic(uid)?.let { ch ->
                            g.setCharacteristicNotification(ch, true)
                            g.enableNotifications(ch)
                        }
                    }
                }
            }
            override fun onCharacteristicChanged(g: BluetoothGatt, ch: BluetoothGattCharacteristic) {
                val p = parse(ch.value) ?: return
                when (ch.uuid) { CHR_HEAD -> listener?.onHead(p); CHR_TRUNK -> listener?.onTrunk(p) }
            }
        })
    }

    private fun BluetoothGatt.enableNotifications(ch: BluetoothGattCharacteristic) {
        val cfg = ch.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")) ?: return
        cfg.value = byteArrayOf(1, 0)   // GATT CLIENT_CHARACTERISTIC_CONFIG enable
        @Suppress("DEPRECATION")
        writeDescriptor(cfg)
    }

    private fun parse(v: ByteArray?): ImuPacket? {
        if (v == null || v.size < 20) return null
        fun i16(o: Int) = ((v[o + 1].toInt() shl 8) or (v[o].toInt() and 0xFF)).toInt()
        return ImuPacket(
            seq = i16(0).toInt() and 0xFFFF,
            pitch = i16(2) / 100.0, roll = i16(4) / 100.0, yaw = i16(6) / 100.0,
            ax = i16(8), ay = i16(10), az = i16(12),
            gx = i16(14), gy = i16(16), gz = i16(18)
        )
    }

    fun disconnect() { gatt?.close(); connected = false }
}
