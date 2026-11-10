# 🚀 Pelatihan Flutter Lanjutan — Level Advanced (5 Hari)

> Lanjutan dari seri **[Flutter Belajar Materis](https://materis.vercel.app)**. Di sana, bagian *"Coming soon"* menjanjikan **offline support, push notification, caching, E2E testing, dan performance optimization** — pelatihan ini menuntaskan semuanya, lalu naik ke level **advanced**: arsitektur modular, keamanan jaringan, real-time, kode native, observability, dan AI.

## 🧭 Prinsip Pelatihan Ini

Peserta **sudah** pernah membuat katalog + keranjang (`product_list_demo`), login JWT (`day4`), MVVM + backend (`day6`, `day7`), serta testing & CI (`day9` SimpleGovHR). Karena itu:

* **Tidak mengulang** dasar (widget, form, `FutureBuilder`, `provider`, repository, test dasar, CI dasar). Hal yang sudah dikuasai cukup di-*review* lewat **pre-test diagnostik**.
* Kode dasar (UI katalog, form login, tema) disediakan di **starter repo** → waktu lab dipakai untuk hal yang **baru**.
* Capstone dibingkai sebagai **upgrade aplikasi lama** (`product_list_demo`: Provider/StateNotifier, `http`, tanpa offline) menjadi **TokoKu Pro** production-grade. Memigrasikan kode lama secara bertahap adalah skill inti developer senior.

## 🎯 Hasil Akhir

Setiap peserta memiliki **TokoKu Pro** dengan:

| Area | Yang dibangun | Status vs materi sebelumnya |
|---|---|---|
| Arsitektur | **Pub workspace** (monorepo) + paket `tokoku_core` + `riverpod_lint` | 🆕 Baru |
| Bahasa | Dart 3.10–3.13: *dot shorthands*, *primary constructors*, sealed + pattern matching | 🆕 Baru |
| State | **Riverpod 3 + codegen** (migrasi dari `StateNotifier`) | ⬆️ Upgrade |
| Jaringan | Dio + **refresh token antre (QueuedInterceptor)** + **certificate pinning** | 🆕 Baru |
| Navigasi | **go_router**: auth guard yang menjaga deep link, `StatefulShellRoute` | 🆕 Baru |
| Data | **drift** offline-first, migrasi skema, outbox sync, **background sync (workmanager)** | 🆕 Baru |
| Real-time | **WebSocket** status pesanan + reconnect backoff | 🆕 Baru |
| Native | **Pigeon** (platform channel type-safe, Kotlin) | 🆕 Baru |
| Testing | mocktail, fake adapter, drift in-memory, **Patrol**, **alchemist**, leak tracking | ⬆️ Upgrade |
| Produksi | FCM + deep link, Crashlytics, **Remote Config feature flag**, **Gemini (Firebase AI Logic)**, App Check | 🆕 Baru |
| Rilis | Flavor + `--dart-define-from-file`, signing dari secrets, **upload otomatis ke Play** | ⬆️ Upgrade |

## 📋 Prasyarat (sesuai materi & repo latihan sebelumnya)

| Materi/Repo Sebelumnya | Isi Sebenarnya | Di-upgrade Di |
|---|---|---|
| `day3` (materis) | `http` + `FutureBuilder` + `GridView` | Hari 1 (pre-test) |
| `day4` / `auth` (materis) | Login JWT, `flutter_secure_storage`, `provider`, `local_auth` | Hari 2 (refresh token antre, sesi berakhir) |
| `implementasi/multi-language` (materis) | Riverpod 2 **`StateNotifier`** + `shared_preferences` | Hari 1 (migrasi ke `Notifier` codegen) |
| `implementasi/environment-variables` (materis) | `flutter_dotenv`, `.env` dibundel sebagai aset | Hari 2 (**dikoreksi**: `--dart-define-from-file`) |
| `product_list_demo` | Provider + Riverpod 2 (`StateNotifier`, `AsyncNotifier` manual), repository + `Result` | Capstone (di-upgrade menjadi TokoKu Pro) |
| `day6` Tax Retribution | MVVM + `provider` + backend FastAPI + biometrik | Hari 1 (pemetaan MVVM → feature-first) |
| `day7` | Validasi form + backend Go | — (disediakan di starter) |
| `day9` SimpleGovHR, `flutter_test` | mockito, integration_test, golden_toolkit, codecov, CI matrix | Hari 4–5 (mocktail, Patrol, alchemist, release ke Play) |
| `flutter_prod_guide` (materis) | Crashlytics, obfuscate, staged rollout | Hari 5 (feature flag, App Check, AI) |

### 🛠️ Setup Wajib (sebelum Hari 1)

```bash
flutter upgrade            # Wajib Flutter 3.47.x stable (Dart 3.13)
flutter --version
flutter doctor             # Android toolchain & emulator harus ✓
dart --version             # 3.13.x
```

* Repo latihan lama dibuat dengan Flutter **3.35 / Dart 3.9**. Jalankan `flutter pub upgrade --major-versions` dan `dart fix --apply` di `product_list_demo` sebagai pemanasan (lihat Hari 1).
* VS Code / Android Studio + ekstensi Flutter & Dart.
* Emulator Android (API 35+) atau HP Android dengan USB debugging.
* Akun GitHub; akun Google untuk Firebase (Hari 5).
* (Opsional, disarankan) asisten AI yang mendukung MCP — lihat Hari 1, Sesi 6.

::: warning Catatan versi (November 2026)
Materi divalidasi dengan **Flutter 3.47.9 / Dart 3.13.7**, `flutter_riverpod 3.5`, `riverpod_generator 4.0`, `riverpod_lint 3.2`, `go_router 18.1`, `freezed 4.0`, `drift 2.35`, `dio 5.11`, `workmanager 0.10`, `pigeon 29`, `patrol 4.11`, `firebase_messaging 17`, `firebase_ai 5.1`. Flutter **3.50** (rilis stable November 2026) menjadwalkan *deprecation* `package:flutter/material.dart` → capstone sudah memakai **`material_ui`** (Hari 1).
:::

## 🗓️ Silabus

Setiap hari **08:00–16:00** (7 jam efektif + 1 jam ISHOMA).

| Hari | Tema | Topik Advanced | Output Capstone |
|---|---|---|---|
| [Hari 1](./day1) | Arsitektur Modern & Dart 3.13 | Pre-test diagnostik, upgrade 3.35→3.47, **pub workspace + riverpod_lint**, Dart 3.10–3.13, migrasi `material_ui`, **migrasi StateNotifier → Notifier codegen**, freezed union, MCP server | Workspace TokoKu Pro + `tokoku_core` + katalog paginasi |
| [Hari 2](./day2) | Jaringan Aman & Navigasi | Refresh token antre (`QueuedInterceptor`) + sesi berakhir, **certificate pinning**, **koreksi `.env` → dart-define**, go_router guard yang menjaga deep link | Login → katalog → detail → pencarian, bottom nav, deep link |
| [Hari 3](./day3) | Offline-First & Real-time | drift + migrasi + outbox, race condition sync, **workmanager background sync**, **WebSocket + reconnect**, Riverpod offline persistence (eksperimental) | Keranjang offline + sync di background + status pesanan live |
| [Hari 4](./day4) | Kualitas, Performa & Native | Test Riverpod/interceptor/stream, **Patrol** (dialog native), **alchemist**, leak tracking, profiling + isolate, **Pigeon** | Suite test ≥ 70%, laporan profiling, info perangkat dari Kotlin |
| [Hari 5](./day5) | Produksi, AI & Rilis | FCM + deep link, Crashlytics, **App Check**, **Remote Config feature flag**, **Gemini via Firebase AI Logic**, flavor, CI/CD → Play, Shorebird, presentasi | AAB di internal testing + ringkasan produk AI + demo |

## 🧱 Struktur Akhir Capstone

```
capstone/                          # root pub workspace + app Flutter
 ┣ pubspec.yaml                    # workspace: [packages/tokoku_core]
 ┣ packages/tokoku_core/           # murni Dart: Money (primary constructor)
 ┣ pigeons/device_api.dart         # kontrak Dart <-> Kotlin
 ┣ tool/order_status_server.dart   # server WebSocket untuk lab
 ┣ config/{dev,dev_firebase,prod}.json
 ┗ lib/
   ┣ core/
   ┃ ┣ config/      env.dart, feature_flags.dart (Remote Config)
   ┃ ┣ database/    app_database.dart (drift)
   ┃ ┣ error/       failure.dart (sealed)
   ┃ ┣ network/     dio_client, auth_interceptor, certificate_pinning, session_events
   ┃ ┣ platform/    device_api.g.dart (Pigeon), device_info_provider.dart
   ┃ ┗ storage/, settings/, utils/
   ┣ features/
   ┃ ┣ auth/  products/  cart/  orders/  ai/  notifications/
   ┣ router/        app_router.dart (authRedirect murni + go_router)
   ┗ app.dart, main.dart
 test/ (unit, widget, golden)   integration_test/   patrol_test/
```

Kode referensi lengkap (lolos `flutter analyze` dan `flutter test`) tersedia di folder `capstone/` yang menyertai materi ini. Semua potongan kode di materi diambil langsung dari folder tersebut.

## 📏 Metode & Penilaian

* 25% teori/demo, 75% praktik (hands-on lab). Setiap lab punya **checklist** yang bisa diverifikasi.
* Pre-test diagnostik (Hari 1) & post-test (Hari 5) dengan soal yang sama → mengukur peningkatan.
* Setiap hari: kuis singkat + tugas rumah dikumpulkan sebagai **Pull Request** (CI harus hijau).
* Penilaian akhir: capstone (50%), tugas harian (30%), kuis & post-test (20%).
* Kapasitas presentasi Hari 5: **maks. 7 peserta/tim** per kelas (90' / ±12' per presentasi). Kelas lebih besar → presentasi per tim 2–3 orang.
