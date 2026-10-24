# PAJ Delivery Forwarder (Merchant Phone Companion App)

A lightweight Android background app running on the **Cashier Phone** (where official GrabMerchant and Shopee Partner are installed).

---

## 🎯 What It Does
1. Watches for incoming order pop-ups from **GrabMerchant** (`com.grab.merchant`) and **Shopee Partner** (`com.shopee.sellercenter`).
2. Extracts Order ID (e.g., `#GF-4921` or `#14`), items with quantities, and customer notes.
3. Posts the order in real time over local store Wi-Fi to the **PAJ POS Tablet**:
   `POST http://<TABLET_IP>:8088/api/delivery/order`

---

## 📱 In-App Setup (One-Time)
1. Open **PAJ Delivery Forwarder** on the phone.
2. Enter the **Tablet IP address** (e.g., `192.168.1.150`) and port `8088`.
3. Tap **Simpan & Tes Koneksi ke Tablet** (verifies connectivity).
4. Tap **Buka Pengaturan Aksesibilitas HP** and toggle ON **"PAJ Grab & Shopee Order Forwarder"**.
5. Done! The app runs silently in the background and forwards orders whenever Grab or Shopee receives one.
