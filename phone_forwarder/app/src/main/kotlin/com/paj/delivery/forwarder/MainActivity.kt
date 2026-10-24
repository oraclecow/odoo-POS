package com.paj.delivery.forwarder

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class MainActivity : Activity() {

    private val executor = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val prefs = getSharedPreferences("paj_forwarder_prefs", Context.MODE_PRIVATE)

        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(50, 60, 50, 60)
        }

        val title = TextView(this).apply {
            text = "PAJ Delivery Forwarder (Phone)"
            textSize = 20f
            setTypeface(null, android.graphics.Typeface.BOLD)
            setTextColor(android.graphics.Color.DKGRAY)
        }
        layout.addView(title)

        val subtitle = TextView(this).apply {
            text = "Meneruskan order GrabFood & ShopeeFood ke Tablet POS secara otomatis via Wi-Fi."
            textSize = 13f
            setPadding(0, 10, 0, 40)
        }
        layout.addView(subtitle)

        val labelIp = TextView(this).apply {
            text = "Alamat IP Tablet PAJ POS:"
            textSize = 14f
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
        layout.addView(labelIp)

        val inputIp = EditText(this).apply {
            hint = "Contoh: 192.168.1.150"
            setText(prefs.getString("tablet_ip", "192.168.1.150"))
        }
        layout.addView(inputIp)

        val labelPort = TextView(this).apply {
            text = "Port HTTP Tablet (Default: 8088):"
            textSize = 14f
            setTypeface(null, android.graphics.Typeface.BOLD)
            setPadding(0, 20, 0, 0)
        }
        layout.addView(labelPort)

        val inputPort = EditText(this).apply {
            hint = "8088"
            inputType = android.text.InputType.TYPE_CLASS_NUMBER
            setText(prefs.getInt("tablet_port", 8088).toString())
        }
        layout.addView(inputPort)

        val btnSaveAndPing = Button(this).apply {
            text = "Simpan & Tes Koneksi ke Tablet"
            setBackgroundColor(android.graphics.Color.parseColor("#00B14F"))
            setTextColor(android.graphics.Color.WHITE)
            setPadding(0, 20, 0, 20)
        }
        layout.addView(btnSaveAndPing)

        val btnOpenAccessibility = Button(this).apply {
            text = "Buka Pengaturan Aksesibilitas HP"
            setPadding(0, 20, 0, 20)
        }
        layout.addView(btnOpenAccessibility)

        btnSaveAndPing.setOnClickListener {
            val ip = inputIp.text.toString().trim()
            val portStr = inputPort.text.toString().trim()
            val port = portStr.toIntOrNull() ?: 8088

            prefs.edit().putString("tablet_ip", ip).putInt("tablet_port", port).apply()

            Toast.makeText(this, "Menguji koneksi ke http://$ip:$port/api/status...", Toast.LENGTH_SHORT).show()

            executor.execute {
                try {
                    val url = URL("http://$ip:$port/api/status")
                    val conn = url.openConnection() as HttpURLConnection
                    conn.connectTimeout = 3000
                    conn.readTimeout = 3000
                    val code = conn.responseCode
                    conn.disconnect()

                    runOnUiThread {
                        if (code == 200) {
                            Toast.makeText(this@MainActivity, "✅ Terhubung ke Tablet POS!", Toast.LENGTH_LONG).show()
                        } else {
                            Toast.makeText(this@MainActivity, "⚠️ Tablet merespons HTTP $code", Toast.LENGTH_LONG).show()
                        }
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        Toast.makeText(this@MainActivity, "❌ Gagal terhubung ke Tablet: ${e.message}", Toast.LENGTH_LONG).show()
                    }
                }
            }
        }

        btnOpenAccessibility.setOnClickListener {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        }

        setContentView(layout)
    }
}
