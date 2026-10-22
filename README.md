# 🛒 Open Odoo POS

> **A high-performance, native cross-platform Point of Sale (POS) client for Odoo ERP (v17, v18, and v19) built with Flutter.**  
> Native Windows Desktop • Linux Desktop • Android Tablets • Zero Odoo Server Addons Required.

[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL_3.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Odoo Compatibility](https://img.shields.io/badge/Odoo-17%20%7C%2018%20%7C%2019-714B67?logo=odoo)](https://www.odoo.com)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20Android-lightgrey)](https://github.com)

---

## ⚡ Why Open Odoo POS?

Standard Odoo Point of Sale operates as an in-browser Single Page Application (Owl/Chromium). While versatile, running browser POS on budget retail hardware (e.g. Intel N100/N150 mini-PCs, Celeron, or Android tablets) introduces well-known operational bottlenecks:

* **Heavy Memory Overhead:** Chrome/Edge easily consumes **1.2 GB to 1.8 GB of RAM**, leading to browser tab sluggishness and garbage collection pauses during rapid barcode scanning.
* **Aggressive Server Polling:** Constant background polling loops (`update_customer_display`, `/websocket` reconnect attempts, and image refetches) generate **8,000+ HTTP requests/day per terminal**.
* **Printing Complexity:** Receipt printing in browsers requires either clicking through system print dialogs, configuring virtual printer drivers, or buying an expensive **Odoo IoT Box / PosBox ($150–$300/unit)**.

**Open Odoo POS solves this by delivering a compiled, native desktop and tablet binary:**
* 🚀 **~300 MB Flat RAM Usage** (75% less memory than Chromium).
* 📉 **90% Reduction in Server Traffic** (replaces background polling loops with targeted JSON-RPC calls).
* 🖨️ **Direct Hardware Printing:** Native ESC/POS thermal printing over **Raw TCP Socket (port 9100)**, direct USB spooler, and RJ11 cash drawer kicks—**no IoT Box needed**.
* 🔌 **Zero Server-Side Addons:** Works out-of-the-box with vanilla Odoo Community and Enterprise.

---

## 📊 Real-World Production Benchmark

Tested in live retail supermarket operations across a full **13.5-hour operational day** (Intel N150 quad-core mini-PC, 183 completed customer orders):

| Metric | Odoo Web Client (Chrome) | **Open Odoo POS (Native)** | Improvement |
| :--- | :--- | :--- | :--- |
| **Client Memory (RAM)** | 1,450 MB – 1,800 MB | **~300 MB flat** | **~80% reduction** |
| **Server HTTP Calls / Day** | 9,134 requests | **936 requests** | **89.7% reduction** |
| **Network Requests / Order** | ~58 calls / order | **~5.1 calls / order** | **91% less server load** |
| **Order Sync Latency** | 350 ms – 600 ms | **211 ms avg (p95: 458 ms)** | **Faster checkout** |
| **Partner & Loyalty Lookup** | 120 ms – 250 ms | **15 ms – 16 ms** | **Instant response** |
| **Application Errors / Crashes** | Browser tab reload needed | **0 errors / 0 crashes** | **100% uptime** |

---

## ✨ Features

- **Standard Odoo ORM Synchronization:**
  - Direct JSON-RPC connection (`/jsonrpc` / `call_kw`).
  - Supports `pos.order.sync_from_ui` with full payment method registration.
  - Multi-company and multi-register profile switching.
  - Odoo Session lifecycle: Opening float entry, real-time sales ledger, and closing physical cash count (Z-Report).
- **Direct Thermal Printing & Hardware:**
  - **Network LAN (RAW TCP port 9100):** Stream ESC/POS bytes directly to thermal printer IP.
  - **USB Direct Spooler:** Direct Windows spooler integration for local 58mm / 80mm receipt printers.
  - **Epson ePOS:** HTTP XML print support.
  - **RJ11 Cash Drawer Kick:** Standard pulse command (`ESC p 0 25 250`) on cash transactions or manual "Open Drawer" action.
  - **Auto-Cutter Control:** Smart cut formatting for 80mm printers; safe no-cut formatting for 58mm paper rolls.
- **Retail & Supermarket Capabilities:**
  - **Focus-Independent Barcode Scanner Wedge:** Listens directly to keyboard wedge input without requiring the search box to be focused.
  - **In-Memory Catalog Caching:** Synchronizes products at boot; instant instant item matching without database lag.
  - **BOM / Phantom Kit Handling:** Automatic kit detection so component stock is evaluated accurately.
  - **Live Customer Loyalty Points:** Direct lookup of Odoo `loyalty.card` balances (point-per-currency calculations).
  - **Security:** PIN-protected cashier switching, cash in/out management, and admin settings protection.

---

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────┐
│             Open Odoo POS (Flutter Client)             │
│   Native Win32 / Direct3D  •  Linux GTK  •  Android    │
└──────────────┬──────────────────────────┬──────────────┘
               │                          │
       Raw TCP / ESC-POS               JSON-RPC
        (Port 9100/USB)              (Port 8069)
               │                          │
               ▼                          ▼
┌────────────────────────┐      ┌────────────────────────┐
│ Thermal Receipt Printer│      │    Odoo ERP Server     │
│   & RJ11 Cash Drawer   │      │  (v17, v18, v19 Core)  │
└────────────────────────┘      └────────────────────────┘
```

---

## 🚀 Quickstart & Building

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.13+ or higher)
* For Windows Desktop: Visual Studio 2022 with **Desktop development with C++** workload.

### 1. Clone & Install Dependencies
```bash
git clone https://github.com/oraclecow/odoo-POS.git
cd odoo-POS
flutter pub get
```

### 2. Run Locally in Development
```bash
# Run on Windows Desktop
flutter run -d windows

# Run on Linux Desktop
flutter run -d linux

# Run on connected Android tablet
flutter run -d <device_id>
```

### 3. Build Production Releases
```bash
# Windows Native Release Bundle (output in build/windows/x64/runner/Release/)
flutter build windows --release

# Android APK for Tablet Deployments
flutter build apk --release
```

---

## ⚙️ Initial Setup & Configuration Reference

When launched for the first time before connecting to an Odoo server, the app starts in **Demo Mode** with 6 sample products so you can test the cart, barcode input, discounts, and receipt previews immediately.

To connect to your live Odoo ERP server:

1. Click **Server Setup** on the top banner (or open **Cashier Menu → Admin (default PIN: `1234`) / Configure Odoo Server & Register**).
2. Fill in your Odoo instance details using the table below:

| Setting Field | Default Placeholder | What Should Be There & Where to Find It in Odoo |
| :--- | :--- | :--- |
| **Odoo Server URL** | `http://localhost:8069` | Your Odoo server address and port (e.g., `http://192.168.1.100:8069` on LAN or `https://erp.yourdomain.com`). |
| **Database Name** | `odoo` | Exact PostgreSQL database name of your Odoo instance (visible at `/web/database/manager`). |
| **Login / Username** | `admin` | Odoo user email/login with Point of Sale User/Administrator rights. *(Best practice: create a dedicated POS agent user per store).* |
| **Password** | *(empty)* | Password or Odoo API key for the user above. |
| **POS Config ID** | `1` | Database ID (`pos.config`) of the register. In Odoo Web, go to **Point of Sale → Configuration → Point of Sale**, open your register, and look at the URL (`id=2` or enable Developer Mode → View Metadata). |
| **Company ID** | `1` | Database ID (`res.company`) of the store's company. In single-company setups this is always `1`. In multi-company setups, check **Settings → Users & Companies → Companies**. |
| **Register Display Name** | `Main Store POS` | Store name displayed in the top bar and printed as the main title on thermal receipts. |
| **Receipt Header** | `Point of Sale Receipt` | Store street address and phone number printed below the store name on receipts and Z-Reports. |
| **Receipt Footer** | `Thank you for your business!` | Custom return policy, Wi-Fi password, or thank-you message printed at the bottom of customer receipts. |
| **Admin PIN** | `1234` | Local supervisor PIN used to lock server settings, manual price/discount overrides, and returns. |

3. Click **Test Connection & Sync Catalog**.
4. Configure your thermal printer under **Cashier Menu → Printer Settings**:
   * **USB Local (Windows Spooler):** Select for direct USB thermal printers (default printer name: `58mm Series Printer` or `80mm Series Printer`).
   * **Network LAN (RAW TCP 9100):** Select for Ethernet/Wi-Fi thermal printers and enter the printer's static LAN IP (e.g., `192.168.1.100`, port `9100`).
   * **Epson ePOS (HTTP XML):** Select for Epson ePOS-enabled printers (`http://<printer-ip>/cgi-bin/epos/service.cgi?devid=local_printer`).
   * **Disabled (Silent / Simulation):** Previews formatted receipts on-screen without sending bytes to hardware.

### Customizing Store Branding & Defaults (For Pre-Configured Builds)
If you are compiling custom binaries for multiple store branches and want your settings pre-filled:
* **Store Logo:** Replace `assets/images/store_logo.png` with your own square PNG logo.
* **Default Profile:** Edit `OdooCompanyProfile.defaultDemoProfile` in [`lib/data/services/odoo_client.dart`](lib/data/services/odoo_client.dart) with your default server URL, database, and register profile.
* **Payment Methods:** The app automatically queries `pos.payment.method` assigned to your `pos.config` in Odoo and maps Cash (`is_cash_count = true`), Bank/Transfer/QRIS, and delivery aggregators (`GrabFood`, `ShopeeFood`).
* **Fixed Cart Discounts & Loyalty Points:** Percentage discounts work natively on all Odoo lines. For fixed-amount cart discounts or loyalty point redemptions, the app automatically uses the `discount_product_id` configured on your Odoo `pos.config` (or any POS product named `Discount` / `Diskon` / `Loyalty`).

---

## ⚖️ License & Commercial Support

This project is licensed under the **[GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE)**.

* **Open Source Use:** You are free to use, modify, and distribute this software under the terms of the AGPL-3.0. If you modify or run this software as a network service, you must release your changes under the same license.
* **Commercial / Proprietary Licensing:** If you or your organization wish to integrate Open Odoo POS into a closed-source proprietary offering, rebrand/whitelabel it for resale, or require a commercial license exempt from AGPL copyleft requirements, please contact the maintainer.
* **Custom Development & Consulting:** Custom hardware integration, payment terminal integrations (EDC, QRIS, Stripe, Adyen), or custom Odoo workflow customization is available on a consulting basis.

---

## ☕ Support the Author & Contributing

If this project saved you hundreds of dollars on Odoo IoT Boxes or hours of developer frustration:

* ⭐ **Star this repository** on GitHub!
* 💖 **[Sponsor on GitHub Sponsors](https://github.com/sponsors/oraclecow)** to support maintenance and future Odoo version updates.

### 🛠️ Behind the Code & Community Contributions
This application was created by a retail business owner pairing with **Google Antigravity (AG)** to solve real-world cashier latency, memory bloat, and thermal printing challenges in live store operations.

* **Operational Reality:** I am a business owner with an IT hobby/background, not a full-time software developer. The application was built from a practical, store-floor operational perspective to get the job done reliably on budget hardware.
* **Code Contributions Welcomed:** While the app runs daily in live production with zero crashes and passes standard Dart analysis, performance profiling, architectural refactoring, and code cleanup from seasoned Flutter/Dart developers are warmly welcomed!
* If you see areas where state management, widget trees, or networking can be optimized or tightened, please feel free to open an issue or submit a pull request!


## Modes & Receipts

- **Business modes:** one codebase, two modes — `retail` (stock badges, kits) and `fnb` (modifiers, order channels, kitchen slip). Switch in *Server Setup → Business Mode*, or per profile via `web/pos_config.json`.
- **Modular receipts:** all receipt layouts live in `lib/modules/pos_receipt/`. Edit text/toggles in `web/receipt_config.json` (no recompile), or set `"use_odoo_original_format": true` to print the standard Odoo receipt layout.
- **Session open/close UI:** `lib/modules/pos_session/`.
