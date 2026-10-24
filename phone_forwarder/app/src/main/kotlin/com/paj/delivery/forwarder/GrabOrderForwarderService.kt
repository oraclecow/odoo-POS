package com.paj.delivery.forwarder

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class GrabOrderForwarderService : AccessibilityService() {

    private val TAG = "PAJ_ForwarderService"
    private val executor = Executors.newSingleThreadExecutor()

    // Deduplication cache: orderId -> timestamp
    private val processedOrders = HashMap<String, Long>()

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return

        val isGrab = pkg == "com.grab.merchant"
        val isShopee = pkg.contains("shopee")

        if (!isGrab && !isShopee) return

        val rootNode = rootInActiveWindow ?: return

        try {
            val allTexts = mutableListOf<String>()
            extractAllTexts(rootNode, allTexts)

            if (allTexts.isEmpty()) return

            val platform = if (isGrab) "grabfood" else "shopeefood"
            val orderId = findOrderId(allTexts, isGrab) ?: return

            // Deduplicate: avoid resending same order within 2 minutes
            val now = System.currentTimeMillis()
            val lastTime = processedOrders[orderId]
            if (lastTime != null && (now - lastTime) < 120_000) {
                return
            }

            val items = parseOrderItems(allTexts)
            if (items.isEmpty()) return

            processedOrders[orderId] = now

            val payload = JSONObject().apply {
                put("id", "phone_${System.currentTimeMillis()}")
                put("order_id", orderId)
                put("platform", platform)
                put("customer_name", findCustomerName(allTexts) ?: "Pelanggan Online")
                put("source", "phone_accessibility")

                val itemsArray = JSONArray()
                for (it in items) {
                    itemsArray.put(JSONObject().apply {
                        put("name", it.first)
                        put("quantity", it.second)
                    })
                }
                put("items", itemsArray)
            }

            val prefs = getSharedPreferences("paj_forwarder_prefs", Context.MODE_PRIVATE)
            val tabletHost = prefs.getString("tablet_ip", "192.168.1.150") ?: "192.168.1.150"
            val tabletPort = prefs.getInt("tablet_port", 8088)

            Log.d(TAG, "New $platform order #$orderId found! Dispatching to http://$tabletHost:$tabletPort...")
            dispatchToTablet(tabletHost, tabletPort, payload)

        } catch (e: Exception) {
            Log.e(TAG, "Error parsing order screen", e)
        }
    }

    override fun onInterrupt() {}

    private fun extractAllTexts(node: AccessibilityNodeInfo?, result: MutableList<String>) {
        if (node == null) return
        val text = node.text?.toString()?.trim()
        if (!text.isNullOrEmpty()) {
            result.add(text)
        }
        for (i in 0 until node.childCount) {
            extractAllTexts(node.getChild(i), result)
        }
    }

    private fun findOrderId(texts: List<String>, isGrab: Boolean): String? {
        val grabRegex = Regex("""(?:GF-|\b#)(\d{3,6})\b""", RegexOption.IGNORE_CASE)
        val shopeeRegex = Regex("""(?:No\.?\s*#?|#)(\d{1,4})\b""", RegexOption.IGNORE_CASE)

        for (t in texts) {
            val regex = if (isGrab) grabRegex else shopeeRegex
            val match = regex.find(t)
            if (match != null) {
                return match.groupValues[1]
            }
        }
        return null
    }

    private fun findCustomerName(texts: List<String>): String? {
        for (i in texts.indices) {
            val t = texts[i].lowercase()
            if (t.contains("pemesan") || t.contains("pelanggan") || t.contains("customer")) {
                if (i + 1 < texts.size) {
                    val next = texts[i + 1].trim()
                    if (next.isNotEmpty() && !next.startsWith("#")) {
                        return next
                    }
                }
            }
        }
        return null
    }

    private fun parseOrderItems(texts: List<String>): List<Pair<String, Int>> {
        val items = mutableListOf<Pair<String, Int>>()
        val qtyRegex = Regex("""^(\d+)\s*[xX]\s+(.+)$""")

        for (t in texts) {
            val match = qtyRegex.find(t)
            if (match != null) {
                val qty = match.groupValues[1].toIntOrNull() ?: 1
                val name = match.groupValues[2].trim()
                if (name.isNotEmpty() && !name.lowercase().contains("total") && !name.lowercase().contains("subtotal")) {
                    items.add(Pair(name, qty))
                }
            }
        }
        return items
    }

    private fun dispatchToTablet(host: String, port: Int, payload: JSONObject) {
        executor.execute {
            try {
                val url = URL("http://$host:$port/api/delivery/order")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.connectTimeout = 4000
                conn.readTimeout = 4000
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json; utf-8")

                OutputStreamWriter(conn.outputStream).use { writer ->
                    writer.write(payload.toString())
                    writer.flush()
                }

                val code = conn.responseCode
                Log.d(TAG, "Sent to Tablet POS successfully. HTTP: $code")
                conn.disconnect()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to reach Tablet at $host:$port: ${e.message}")
            }
        }
    }
}
