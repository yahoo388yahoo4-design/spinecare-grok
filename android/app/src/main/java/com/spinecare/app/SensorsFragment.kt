package com.spinecare.app

import android.annotation.SuppressLint
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.fragment.app.Fragment

class SensorsFragment : Fragment() {
    override fun onCreateView(i: LayoutInflater, c: ViewGroup?, s: Bundle?): View {
        val ctx = requireContext()
        val root = ScrollView(ctx)
        val col = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL; setPadding(32, 32, 32, 32) }
        root.addView(col)

        fun h(t: String) = TextView(ctx).apply { text = t; setTextColor(0xFF38BDF8.toInt()); textSize = 19f; setPadding(0, 20, 0, 6) }
        fun p(t: String) = TextView(ctx).apply { text = t; setTextColor(0xFFE5E7EB.toInt()); textSize = 13f; setPadding(0, 2, 0, 2) }

        col.addView(h("GPU coaching server"))
        val url = EditText(ctx).apply {
            setText(ServerConfig.url(ctx)); setTextColor(0xFFE5E7EB.toInt()); setSingleLine()
        }
        val status = TextView(ctx).apply { setTextColor(0xFF94A3B8.toInt()) }
        col.addView(url)
        col.addView(Button(ctx).apply {
            text = "Test connection"
            setOnClickListener {
                ServerConfig.setUrl(ctx, url.text.toString())
                Thread {
                    val ok = try {
                        val conn = java.net.URL(ServerConfig.url(ctx) + "/health").openConnection() as java.net.HttpURLConnection
                        conn.connectTimeout = 3000; conn.readTimeout = 3000
                        conn.responseCode == 200
                    } catch (e: Exception) { false }
                    activity?.runOnUiThread { status.text = if (ok) "✓ Server reachable (GPU pose ready)" else "✗ Not reachable — app will use on-device pose" }
                }.start()
            }
        })
        col.addView(status)

        col.addView(h("Phone sensors (in use)"))
        p("Camera → MediaPipe BlazePose (33 landmarks, on-device GPU)")
        p("Depth/LiDAR → used when the device exposes it (ARCore Depth / FaceMesh scale); otherwise RGB-only")
        p("Accelerometer+gyro → phone posture context, fall/step detection")
        p("Microphone → optional audio cues output only (never recorded)")

        col.addView(h("ESP32 posture nodes (BLE)"))
        p("Two 6-DOF IMU nodes (BMI270 + ESP32-C3): head + upper trunk.")
        p("Service 0xFFF0; notify characteristics 0xFFF1 (head) / 0xFFF2 (trunk).")
        p("Payload: seq, pitch/roll/yaw (0.01°), accel (mg), gyro (0.1 dps) — 20 bytes.")
        p("Firmware source: firmware/esp32_posture_node/ in the project.")
        col.addView(Button(ctx).apply {
            text = "Scan for posture nodes (requires Bluetooth permission)"
            setOnClickListener {
                status.text = "Scanning… (pair the ESP32 node first in system Bluetooth)"
                val mgr = ctx.getSystemService(android.content.Context.BLUETOOTH_SERVICE) as android.bluetooth.BluetoothManager
                val adapter = mgr.adapter
                if (adapter != null && adapter.isEnabled) {
                    @SuppressLint("MissingPermission")
                    adapter.startDiscovery()
                } else status.text = "Bluetooth off or unavailable"
            }
        })

        col.addView(h("What sensors can and cannot measure"))
        p("CAN: body-segment angles, movement tempo, reps, posture trends, activity, sleep position (bed mat).")
        p("CANNOT: vertebral positions, disc protrusions, nerve compression, C6 lesion stability — imaging only.")

        return root
    }
}
