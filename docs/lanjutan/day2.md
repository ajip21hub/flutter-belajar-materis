# Hari 2 — Jaringan Aman & Navigasi Deklaratif

## 🎯 Tujuan Pembelajaran

* Membangun **AuthInterceptor** dengan refresh token yang aman di bawah **request bersamaan** (`QueuedInterceptor` + deduplikasi), tanpa deadlock dan tanpa logout palsu.
* Memutus dependensi melingkar `core ↔ fitur` dengan **event provider** (`SessionExpired`).
* Menerapkan **certificate pinning** pada Dio dan memahami strategi rotasinya.
* **Mengoreksi** pola `flutter_dotenv` dari materi sebelumnya: konfigurasi ditanam saat compile dengan `--dart-define-from-file`, **tanpa secret di app**.
* Membangun navigasi **go_router**: auth guard sebagai **fungsi murni yang menjaga deep link**, `StatefulShellRoute`, deep link `tokoku://`.
* Pencarian dengan **debounce berbasis autoDispose** + `CancelToken`.

## ⏰ Jadwal

| Waktu | Durasi | Sesi |
|---|---|---|
| 08:00 – 08:15 | 15' | Review PR Hari 1 (migrasi StateNotifier) |
| 08:15 – 08:40 | 25' | Dio di level produksi: error mapping, `CancelToken`, interceptor |
| 08:40 – 09:30 | 50' | Teori + demo: refresh token antre, 3 bug klasik |
| 09:30 – 10:00 | 30' | 🔐 Keamanan: koreksi `.env`, certificate pinning |
| 10:00 – 10:10 | 10' | Coffee break |
| 10:10 – 12:00 | 110' | 🧪 **Lab 2A**: auth (interceptor, sesi berakhir, pinning, config) |
| 12:00 – 13:00 | 60' | ISHOMA |
| 13:00 – 13:50 | 50' | Teori + demo: go_router, redirect murni, shell route, deep link |
| 13:50 – 15:30 | 100' | 🧪 **Lab 2B**: router, bottom nav, detail, pencarian, deep link |
| 15:30 – 15:45 | 15' | Kuis harian |
| 15:45 – 16:00 | 15' | Rangkuman & PR |

---

## 📘 Sesi 1 — Dio di Level Produksi (25 menit)

`http` (dipakai di `day3`, `day4`) sudah Anda kuasai. Yang membuat Dio layak untuk produksi: **interceptor**, **`CancelToken`**, timeout per fase, dan adapter yang bisa diganti (dipakai untuk pinning & test).

| `DioExceptionType` | Arti | Map ke |
|---|---|---|
| `connectionError`, `connectionTimeout`, `receiveTimeout`, `sendTimeout` | Jaringan bermasalah | `NetworkFailure` |
| `badResponse` + 401 | Token tidak valid | `UnauthorizedFailure` |
| `badResponse` lain | 4xx/5xx | `ServerFailure(statusCode)` |
| `cancel` | Dibatalkan (`CancelToken`) | diabaikan |

`mapDioError()` sudah ada di `core/error/failure.dart` (Hari 1).

---

## 📘 Sesi 2 — Refresh Token Antre & 3 Bug Klasik (50 menit)

Di `auth.md` (materis) refresh token **disimpan** tetapi tidak pernah dipakai. Begitu access token kedaluwarsa, user dipaksa login ulang. Hari ini kita membuat refresh otomatis — dan membahas 3 bug yang **benar-benar** muncul di app produksi:

```
Request ──► onRequest: tambah "Authorization: Bearer <access>"
                 │
            Server 401?
                 │ ya (onError, diproses ANTRE satu per satu)
                 ▼
   Token yang dipakai request ini == token tersimpan sekarang?
        │ ya                                   │ tidak (request lain sudah refresh)
        ▼                                      ▼
   POST /auth/refresh (Dio TERPISAH)      langsung ulangi dengan token terbaru
        │ 200            │ 400/401/403          │ error jaringan
        ▼                ▼                      ▼
   simpan + ulangi   hapus token +          teruskan error,
   (Dio terpisah)    SessionExpired         user TIDAK di-logout
```

| Bug | Gejala di produksi | Pencegahan di kode |
|---|---|---|
| **Deadlock** | App "kadang hang" tanpa error | Retry memakai `plainDio`, bukan Dio yang memasang `QueuedInterceptor` |
| **Refresh berganda** | 5 request bersamaan → 5× refresh; dengan *refresh token rotation*, 4 di antaranya gagal → user ter-logout | Bandingkan token di request dengan token tersimpan sebelum refresh |
| **Logout palsu** | User di lift/kereta ter-logout karena timeout saat refresh | Hanya hapus token bila server **menolak** (400/401/403) |
| **Handler tidak dipanggil** | Satu exception tak terduga (mis. `TypeError`) → antrean berhenti selamanya | `try/catch` menyeluruh; **setiap** jalur keluar memanggil `handler` |

```dart
// 📄 lib/core/network/auth_interceptor.dart
import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Menyisipkan Bearer token & melakukan refresh otomatis saat 401.
///
/// `QueuedInterceptor` memproses callback SATU PER SATU. Itu saja belum
/// menjamin refresh hanya sekali: jika 5 request gagal 401 bersamaan, kelimanya
/// tetap masuk `onError` berurutan. Karena itu, sebelum refresh kita cek dulu
/// apakah token yang dipakai request ini masih token terbaru. Jika sudah
/// berbeda, berarti request lain di antrean sudah me-refresh -> cukup ulangi.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.storage,
    required this.plainDio,
    this.onSessionExpired,
  });

  final TokenStorage storage;

  /// Dio TANPA interceptor ini, dipakai untuk refresh & retry.
  /// ⚠️ JANGAN retry memakai Dio yang sama: QueuedInterceptor sedang
  /// "mengunci" antrean di onError -> request retry menunggu antrean
  /// yang menunggu dirinya sendiri = DEADLOCK.
  final Dio plainDio;

  /// Dipanggil saat refresh token DITOLAK server (sesi benar-benar habis).
  final void Function()? onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storage.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final is401 = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;
    if (!is401 || alreadyRetried) return handler.next(err);

    // SETIAP jalur keluar wajib memanggil handler. Jika tidak (mis. ada
    // TypeError yang tidak tertangkap), antrean berhenti selamanya -> app hang.
    try {
      var access = await storage.accessToken;
      if (access == null) return handler.next(err); // sudah logout

      final sentWith = err.requestOptions.headers['Authorization'];
      if (sentWith == 'Bearer $access') {
        // Request ini memakai token terbaru -> memang perlu refresh.
        access = await _refresh();
        if (access == null) {
          await storage.clear();
          onSessionExpired?.call();
          return handler.next(err);
        }
      }

      final retryOptions = err.requestOptions
        ..headers['Authorization'] = 'Bearer $access'
        ..extra['retried'] = true;
      final response = await plainDio.fetch<dynamic>(retryOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      // Gangguan jaringan saat refresh/retry: JANGAN logout user.
      return handler.next(e);
    } catch (e, st) {
      return handler.next(
        DioException(
          requestOptions: err.requestOptions,
          error: e,
          stackTrace: st,
        ),
      );
    }
  }

  /// Mengembalikan access token baru, atau `null` jika server MENOLAK
  /// refresh token (400/401/403). Error jaringan dilempar ulang.
  Future<String?> _refresh() async {
    final refresh = await storage.refreshToken;
    if (refresh == null) return null;
    try {
      final res = await plainDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refresh, 'expiresInMins': 30},
      );
      final data = res.data!;
      final access = data['accessToken'] as String;
      await storage.save(
        access: access,
        refresh: data['refreshToken'] as String,
      );
      return access;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 400 || code == 401 || code == 403) return null;
      rethrow;
    }
  }
}
```

### Memutus siklus `core ↔ auth`

`dioProvider` (core) perlu memberi tahu `AuthController` (fitur auth) bahwa sesi habis, tetapi `AuthController` → `AuthRepository` → `dioProvider`. Jika core meng-import auth → **siklus**. Solusi: event provider netral di `core/`:

```dart
// 📄 lib/core/network/session_events.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_events.g.dart';

/// "Bel" sesi berakhir. Dio (lapisan core) membunyikannya, AuthController
/// (fitur auth) mendengarkannya. Dengan begitu `core/` tidak perlu meng-import
/// fitur auth -> tidak ada dependensi melingkar.
@Riverpod(keepAlive: true)
class SessionExpired extends _$SessionExpired {
  @override
  int build() => 0;

  void notify() => state++;
}
```

---

## 📘 Sesi 3 — Keamanan Jaringan & Konfigurasi (30 menit)

### 3.1 Koreksi: `.env` bukan tempat rahasia

Materi `implementasi/environment-variables` memakai `flutter_dotenv` dengan file `.env`, `.env.staging`, `.env.production` yang **didaftarkan sebagai asset** — termasuk `DEMO_PASSWORD`. Asset ikut terkemas di APK/AAB:

```bash
unzip -l app-release.apk | grep .env       # file .env terlihat
unzip -p app-release.apk 'assets/flutter_assets/.env'   # isinya terbaca
```

| Pola lama (materis) | Pola baru |
|---|---|
| `.env*` sebagai asset + `dotenv.load()` saat runtime | `config/<flavor>.json` + `--dart-define-from-file` saat **compile** |
| Password/kredensial demo di `.env` | **Tidak ada secret di app sama sekali** |
| Validasi env saat runtime | Konstanta `String.fromEnvironment` (tree-shaken, bertipe) |

```json
// config/dev.json
{ "FLAVOR": "dev", "API_BASE_URL": "https://dummyjson.com", "ENABLE_FIREBASE": "false" }
```

```dart
// 📄 lib/core/config/env.dart
/// Konfigurasi per-flavor yang ditanam saat compile lewat
/// `--dart-define-from-file=config/<flavor>.json` (lihat Hari 2 & 5).
///
/// ⚠️ Semua nilai di sini BISA diekstrak dari binary. Jangan pernah menaruh
/// secret server (API secret, password, kredensial DB) di sini.
abstract final class Env {
  static const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dummyjson.com',
  );

  /// Firebase (FCM, Crashlytics, Remote Config, AI Logic) baru aktif di Hari 5.
  static const enableFirebase = bool.fromEnvironment('ENABLE_FIREBASE');

  /// Server WebSocket status pesanan (Hari 3). 10.0.2.2 = localhost dari
  /// emulator Android.
  static const wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://10.0.2.2:8080',
  );

  /// SHA-256 sertifikat yang dipercaya (pisahkan dengan koma). Kosong =
  /// certificate pinning nonaktif (Hari 2).
  static const certSha256Pins = String.fromEnvironment('CERT_SHA256_PINS');

  static bool get isDev => flavor == 'dev';
}
```

> ⚠️ `--dart-define` **juga** bisa diekstrak dari binary (lebih sulit, tapi bisa). Aturannya tetap: secret server (API secret, kredensial DB, kunci pembayaran) hanya tinggal di **backend**. App hanya menyimpan nilai publik (URL, flag) dan token milik user (di secure storage).

### 3.2 Certificate pinning

TLS biasa memercayai **semua** CA yang terpasang di perangkat. Di perangkat yang dipasangi CA palsu (proxy kantor, malware, atau penyerang di Wi-Fi publik), lalu lintas HTTPS bisa disadap. Pinning = app hanya menerima sertifikat yang sidik jarinya sudah diketahui.

```dart
// 📄 lib/core/network/certificate_pinning.dart
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Certificate pinning: hanya percaya sertifikat server yang sidik jarinya
/// (SHA-256 dari DER) ada di daftar. Melindungi dari serangan MITM walau
/// perangkat memasang CA palsu (mis. proxy kantor/attacker).
///
/// Ambil sidik jari sertifikat saat ini:
/// ```sh
/// openssl s_client -connect dummyjson.com:443 -servername dummyjson.com \
///   </dev/null 2>/dev/null | openssl x509 -outform DER | openssl dgst -sha256
/// ```
///
/// ⚠️ Sertifikat diperbarui berkala. SELALU pasang minimal 2 pin (aktif +
/// cadangan) dan rencanakan rotasi, atau app lama tidak bisa konek sama sekali.
Set<String> parsePins(String raw) => raw
    .split(',')
    .map((p) => p.trim().toLowerCase().replaceAll(':', ''))
    .where((p) => p.isNotEmpty)
    .toSet();

String sha256Fingerprint(List<int> der) => sha256.convert(der).toString();

bool isPinned(X509Certificate? cert, Set<String> pins) =>
    cert != null && pins.contains(sha256Fingerprint(cert.der));

/// Adapter Dio yang menolak koneksi jika sertifikat tidak cocok.
/// Mengembalikan `null` (pakai adapter default) bila daftar pin kosong.
HttpClientAdapter? pinnedHttpClientAdapter(Set<String> pins) {
  if (pins.isEmpty) return null;
  return IOHttpClientAdapter(
    validateCertificate: (cert, host, port) => isPinned(cert, pins),
  );
}
```

Dipasang di Dio client — berlaku untuk Dio utama **dan** Dio refresh/retry:

```dart
// 📄 lib/core/network/dio_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'certificate_pinning.dart';
import 'session_events.dart';

part 'dio_client.g.dart';

Dio _newDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    ),
  );
  // Pinning berlaku untuk Dio utama MAUPUN Dio refresh/retry.
  final pinned = pinnedHttpClientAdapter(parsePins(Env.certSha256Pins));
  if (pinned != null) dio.httpClientAdapter = pinned;
  return dio;
}

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = _newDio();
  final plainDio = _newDio();
  dio.interceptors.addAll([
    AuthInterceptor(
      storage: ref.watch(tokenStorageProvider),
      plainDio: plainDio,
      // Refresh ditolak -> beri tahu AuthController agar router ke /login.
      onSessionExpired: () =>
          ref.read(sessionExpiredProvider.notifier).notify(),
    ),
    if (kDebugMode)
      LogInterceptor(
        requestBody: true,
        responseBody: false,
        logPrint: (o) => debugPrint('$o'),
      ),
  ]);
  ref.onDispose(() {
    dio.close();
    plainDio.close();
  });
  return dio;
}
```

| Keputusan | Rekomendasi |
|---|---|
| Pin apa? | Minimal 2 pin: sertifikat aktif + cadangan (kunci berikutnya) |
| Saat sertifikat dirotasi? | Rilis app dengan pin baru **sebelum** server berganti sertifikat; sediakan *kill switch* via Remote Config (Hari 5) |
| Aktif di mana? | Hanya `prod` (isi `CERT_SHA256_PINS` di `config/prod.json`). `dev` tanpa pin agar bisa di-debug dengan proxy |

---

## 🧪 Lab 2A — Auth Lengkap (110 menit)

### Langkah 1 — Model user & token storage

```dart
// 📄 lib/features/auth/domain/app_user.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required int id,
    required String username,
    required String email,
    required String firstName,
    required String lastName,
    @Default('') String image,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}
```

```dart
// 📄 lib/core/storage/token_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'token_storage.g.dart';

class TokenStorage {
  TokenStorage(this._storage);
  final FlutterSecureStorage _storage;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _userKey = 'cached_user';

  Future<String?> get accessToken => _storage.read(key: _accessKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshKey);

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  /// Profil terakhir (JSON) agar app tetap "login" saat dibuka offline.
  Future<String?> get cachedUser => _storage.read(key: _userKey);
  Future<void> saveUser(String json) =>
      _storage.write(key: _userKey, value: json);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userKey);
  }
}

@Riverpod(keepAlive: true)
TokenStorage tokenStorage(Ref ref) =>
    TokenStorage(const FlutterSecureStorage());
```

### Langkah 2 — Repository (offline-aware)

```dart
// 📄 lib/features/auth/data/auth_repository.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/app_user.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  AuthRepository(this._dio, this._storage);
  final Dio _dio;
  final TokenStorage _storage;

  Future<AppUser> login(String username, String password) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'username': username, 'password': password, 'expiresInMins': 30},
      );
      final data = res.data!;
      await _storage.save(
        access: data['accessToken'] as String,
        refresh: data['refreshToken'] as String,
      );
      final user = AppUser.fromJson(data);
      await _storage.saveUser(jsonEncode(user.toJson()));
      return user;
    } catch (e) {
      throw mapDioError(e);
    }
  }

  /// User jika token masih valid, `null` jika belum login.
  /// Offline-first: jika jaringan putus, pakai profil tersimpan agar user
  /// tidak "ter-logout" hanya karena sedang di pesawat.
  Future<AppUser?> currentUser() async {
    if (await _storage.accessToken == null) return null;
    try {
      final res = await _dio.get<Map<String, dynamic>>('/auth/me');
      final user = AppUser.fromJson(res.data!);
      await _storage.saveUser(jsonEncode(user.toJson()));
      return user;
    } catch (e) {
      final failure = mapDioError(e);
      if (failure is UnauthorizedFailure) {
        await _storage.clear();
        return null;
      }
      if (failure is NetworkFailure) {
        final cached = await _storage.cachedUser;
        if (cached != null) {
          return AppUser.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        }
      }
      throw failure;
    }
  }

  Future<void> logout() => _storage.clear();
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    AuthRepository(ref.watch(dioProvider), ref.watch(tokenStorageProvider));
```

> Perhatikan `currentUser()`: saat **offline**, profil tersimpan dipakai sehingga user tidak "ter-logout" hanya karena tidak ada sinyal — syarat app offline-first (Hari 3).

### Langkah 3 — Controller (mendengarkan `SessionExpired`)

```dart
// 📄 lib/features/auth/presentation/auth_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/session_events.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

part 'auth_controller.g.dart';

/// Sumber kebenaran status login. `keepAlive` karena dipakai router.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Future<AppUser?> build() {
    // Refresh token ditolak (lihat AuthInterceptor) -> paksa logout.
    ref.listen(sessionExpiredProvider, (_, _) => state = const AsyncData(null));
    return ref.watch(authRepositoryProvider).currentUser();
  }

  Future<void> login(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).login(username, password),
    );
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}
```

### Langkah 4 — Halaman login (UI dari starter)

UI form login + validasi sudah Anda buat di `day7` dan tersedia di starter. Fokus pada dua baris penting:

```dart
// lib/features/auth/presentation/login_page.dart (cuplikan)
ref.listen(authControllerProvider, (prev, next) {      // side-effect SEKALI
  if (next case AsyncError(:final error)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error is Failure ? error.message : 'Login gagal')),
    );
  }
});
final isLoading = ref.watch(authControllerProvider).isLoading;
```

Halaman login **tidak** memanggil `context.go`. Router bereaksi otomatis pada perubahan status auth (Sesi 4).

### Langkah 5 — Uji pinning

```bash
# Ambil sidik jari sertifikat dummyjson saat ini
openssl s_client -connect dummyjson.com:443 -servername dummyjson.com </dev/null 2>/dev/null \
  | openssl x509 -outform DER | openssl dgst -sha256
```

1. Jalankan dengan pin **benar** → katalog termuat.
2. Ubah satu karakter pin → semua request gagal `connectionError` (sertifikat ditolak).

```bash
flutter run --flavor dev --dart-define-from-file=config/dev.json \
  --dart-define=CERT_SHA256_PINS=<sha256-hasil-openssl>
```

✅ **Checklist Lab 2A:**

- [ ] Login sukses; password salah menampilkan SnackBar pesan server
- [ ] Restart app → tetap login (`/auth/me`); restart **dalam mode pesawat** → tetap login (profil tersimpan)
- [ ] Ubah `expiresInMins` login menjadi `1`, tunggu 1 menit, refresh katalog → log: `401` → `POST /auth/refresh` → request diulang sukses
- [ ] Hapus refresh token di storage (simulasi refresh ditolak) → app otomatis kembali ke `/login`
- [ ] Pin salah → request ditolak; pin benar → berhasil
- [ ] `grep -r "DEMO_PASSWORD\|dotenv" lib/` → tidak ada hasil

---

## 📘 Sesi 4 — go_router 18 (50 menit)

> Materi sebelumnya memakai `Navigator.push` + named routes. go_router menambahkan URL sebagai sumber kebenaran → deep link, web, dan guard menjadi alami. Status resmi paket: **feature-complete** (stabil, fokus perbaikan bug).

| Konsep | Penjelasan |
|---|---|
| `GoRoute(path, builder)` | Satu rute; `path` bisa berisi parameter `:id` |
| `context.go('/x')` vs `context.push('/x')` | Ganti stack sesuai URL vs tumpuk halaman |
| `redirect` | Fungsi global → kembalikan path lain atau `null` |
| `refreshListenable` | Memicu evaluasi ulang `redirect` saat state berubah |
| `StatefulShellRoute.indexedStack` | Bottom nav; tiap tab punya navigator & state sendiri |
| `parentNavigatorKey` | Tampilkan rute di navigator root (menutupi bottom nav) |

### Redirect sebagai fungsi murni (bisa di-unit-test)

Bug umum guard: deep link `tokoku://app/products/5` saat app tertutup → status login belum diketahui → `/splash` → `/products`. **Tujuan awal hilang.** Solusinya: bawa tujuan di `?from=`.

```dart
// 📄 lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/profile_page.dart';
import '../features/cart/presentation/cart_page.dart';
import '../features/orders/presentation/order_status_page.dart';
import '../features/products/presentation/product_detail_page.dart';
import '../features/products/presentation/product_list_page.dart';
import '../features/products/presentation/product_search_page.dart';
import 'scaffold_with_nav_bar.dart';

part 'app_router.g.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const products = '/products';
  static const cart = '/cart';
  static const profile = '/profile';
  static String order(String id) => '/orders/$id';
}

/// Fungsi murni -> mudah di-unit-test tanpa widget.
///
/// Aturan:
/// 1. Status awal belum diketahui -> /splash, simpan tujuan di `?from=`.
///    Pengecualian: sedang di /login (proses login berjalan) -> tetap di sana
///    agar LoginPage tidak dibuang & bisa menampilkan error.
/// 2. Belum login -> `/login?from=<tujuan>`.
/// 3. Sudah login tapi di /login atau /splash -> kembali ke `from`.
/// Dengan `from`, deep link & notifikasi saat app tertutup tidak hilang.
String? authRedirect(AsyncValue<Object?> auth, Uri uri) {
  final path = uri.path;
  final atLogin = path == Routes.login;
  final atSplash = path == Routes.splash;
  final from = uri.queryParameters['from'];

  if (auth.isLoading && !auth.hasValue && !auth.hasError) {
    if (atLogin || atSplash) return null;
    return _withFrom(Routes.splash, uri.toString());
  }

  final loggedIn = auth.value != null;
  if (!loggedIn) {
    if (atLogin) return null;
    return _withFrom(Routes.login, atSplash ? from : uri.toString());
  }
  if (atLogin || atSplash) return from ?? Routes.products;
  return null;
}

String _withFrom(String path, String? from) {
  if (from == null ||
      from == Routes.products ||
      from == '/' ||
      from.startsWith(Routes.login) ||
      from.startsWith(Routes.splash)) {
    return path;
  }
  return Uri(path: path, queryParameters: {'from': from}).toString();
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // Jembatan Riverpod -> Listenable agar GoRouter re-evaluasi redirect
  // setiap status auth berubah, TANPA membuat ulang GoRouter.
  final authState = ValueNotifier<AsyncValue<Object?>>(const AsyncLoading());
  ref.onDispose(authState.dispose);
  ref.listen(
    authControllerProvider,
    (_, next) => authState.value = next,
    fireImmediately: true,
  );

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.products,
    refreshListenable: authState,
    debugLogDiagnostics: true,
    redirect: (context, state) => authRedirect(authState.value, state.uri),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/orders/:id', // tampil di navigator root (tanpa bottom nav)
        builder: (_, state) =>
            OrderStatusPage(orderId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ScaffoldWithNavBar(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.products,
                builder: (_, _) => const ProductListPage(),
                routes: [
                  GoRoute(
                    path: 'search', // -> /products/search
                    parentNavigatorKey:
                        _rootKey, // tampil full-screen di atas nav bar
                    builder: (_, _) => const ProductSearchPage(),
                  ),
                  GoRoute(
                    path: ':id', // -> /products/42 (juga untuk deep link)
                    builder: (_, state) => ProductDetailPage(
                      productId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.cart, builder: (_, _) => const CartPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Halaman tidak ditemukan: ${state.uri}')),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
}
```

```dart
// 📄 test/unit/auth_redirect_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokoku_pro/router/app_router.dart';

void main() {
  const loading = AsyncLoading<Object?>();
  const loggedOut = AsyncData<Object?>(null);
  const loggedIn = AsyncData<Object?>('user');

  String? go(AsyncValue<Object?> auth, String location) =>
      authRedirect(auth, Uri.parse(location));

  test('deep link saat status belum diketahui -> splash menyimpan tujuan', () {
    expect(go(loading, '/products/5'), '/splash?from=%2Fproducts%2F5');
  });

  test('status selesai & login -> lanjut ke tujuan awal', () {
    expect(go(loggedIn, '/splash?from=%2Fproducts%2F5'), '/products/5');
  });

  test('belum login -> /login tetap membawa tujuan', () {
    expect(go(loggedOut, '/splash?from=%2Fcart'), '/login?from=%2Fcart');
    expect(go(loggedIn, '/login?from=%2Fcart'), '/cart');
  });

  test('proses login (loading) di /login -> TETAP di /login', () {
    expect(go(loading, '/login'), isNull);
  });

  test('tanpa tujuan khusus -> default ke /products', () {
    expect(go(loading, '/products'), '/splash');
    expect(go(loggedIn, '/splash'), '/products');
  });
}
```

```dart
// 📄 lib/router/scaffold_with_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/cart/presentation/cart_providers.dart';

class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // select(): rebuild hanya saat jumlah item berubah, bukan total harga.
    final count = ref.watch(cartSummaryProvider.select((s) => s.count));
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront),
            label: 'Katalog',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Keranjang',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
```

> 🧩 **Stub Hari 2.** Router & nav bar sudah merujuk `CartPage`, `cartSummaryProvider`, dan `OrderStatusPage` yang baru dibuat Hari 3. Starter menyediakan stub agar kode hari ini bisa di-compile:
>
> ```dart
> // lib/features/cart/presentation/cart_providers.dart (STUB Hari 2)
> @riverpod
> ({int count, Money total}) cartSummary(Ref ref) => (count: 0, total: Money.zero(.usd));
> // cart_page.dart & order_status_page.dart: Scaffold kosong bertuliskan "Hari 3"
> ```

### Deep link

Intent filter sudah ada di `android/app/src/main/AndroidManifest.xml` capstone:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="tokoku" android:host="app" />
</intent-filter>
```

```bash
adb shell am start -a android.intent.action.VIEW -d "tokoku://app/products/5"
```

> Untuk link `https://` (App Links) dibutuhkan `assetlinks.json` di domain Anda — bacaan lanjutan.

---

## 🧪 Lab 2B — Router, Bottom Nav, Detail & Pencarian (100 menit)

### Langkah 1 — Detail produk (family provider)

`productDetailProvider(id)` sudah ada di `product_list_controller.dart`. Halaman detail final (kartu AI dan tombol keranjang aktif mulai Hari 3 & 5):

```dart
// 📄 lib/features/products/presentation/product_detail_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokoku_core/tokoku_core.dart';

import '../../ai/product_ai_service.dart';
import '../../cart/presentation/cart_providers.dart';
import 'product_list_controller.dart';

class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({super.key, required this.productId});
  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(productId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Produk')),
      body: switch (product) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Hero(
              tag: 'product-${value.id}',
              child: AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(
                  imageUrl: value.thumbnail,
                  fit: .contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(value.title, style: Theme.of(context).textTheme.headlineSmall),
            Text(
              '${Money.fromDecimal(value.price, .usd)} • ${value.category} • '
              '⭐ ${value.rating} • stok ${value.stock}',
            ),
            const SizedBox(height: 8),
            _AiSummaryCard(productId: productId),
            Text(value.description),
          ],
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: product.hasValue
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Tambah ke Keranjang'),
                  onPressed: () async {
                    await ref
                        .read(cartActionsProvider)
                        .add(product.requireValue);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ditambahkan ke keranjang')),
                    );
                  },
                ),
              ),
            )
          : null,
    );
  }
}

/// Ringkasan AI (Hari 5). Disembunyikan total bila feature flag mati.
class _AiSummaryCard extends ConsumerWidget {
  const _AiSummaryCard({required this.productId});
  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(productAiSummaryProvider(productId));
    return switch (summary) {
      AsyncData(value: null) => const SizedBox.shrink(),
      AsyncData(:final value?) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text(
                '✨ Ringkasan AI',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(value),
              const SizedBox(height: 4),
              Text(
                'Dibuat oleh AI, bisa keliru.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      // Gagal AI tidak boleh merusak halaman detail -> diam saja.
      AsyncError() => const SizedBox.shrink(),
      _ => const LinearProgressIndicator(),
    };
  }
}
```

> Hari ini: hapus `_AiSummaryCard` & ganti isi `onPressed` dengan SnackBar sementara, atau biarkan memakai stub.

### Langkah 2 — Pencarian dengan debounce tanpa `Timer`

```dart
// 📄 lib/features/products/presentation/product_search_controller.dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/product_repository.dart';
import '../domain/product.dart';

part 'product_search_controller.g.dart';

/// Pencarian dengan debounce 400ms + pembatalan request lama.
@riverpod
Future<List<Product>> productSearch(Ref ref, String query) async {
  if (query.trim().length < 2) return const [];

  // Debounce: tunggu sebentar; jika query berubah, provider ini dibuang
  // (autoDispose) dan request tidak pernah dikirim.
  var disposed = false;
  ref.onDispose(() => disposed = true);
  await Future<void>.delayed(const Duration(milliseconds: 400));
  if (disposed) throw StateError('cancelled');

  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final page = await ref
      .watch(productRepositoryProvider)
      .search(query, cancelToken: cancelToken);
  return page.items;
}
```

Setiap huruf baru = **family key baru** → provider lama di-*dispose* (autoDispose) sebelum delay selesai → request tidak pernah dikirim. Jika request sudah terkirim, `CancelToken` membatalkannya.

```dart
// 📄 lib/features/products/presentation/product_search_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'product_search_controller.dart';

class ProductSearchPage extends ConsumerStatefulWidget {
  const ProductSearchPage({super.key});

  @override
  ConsumerState<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends ConsumerState<ProductSearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(productSearchProvider(_query));
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Cari produk…',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: switch (results) {
        AsyncData(:final value) when value.isEmpty => const Center(
          child: Text('Ketik minimal 2 huruf'),
        ),
        AsyncData(:final value) => ListView.builder(
          itemCount: value.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(value[i].title),
            subtitle: Text('\$${value[i].price}'),
            onTap: () => context.push('/products/${value[i].id}'),
          ),
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const LinearProgressIndicator(),
      },
    );
  }
}
```

### Langkah 3 — Hubungkan ke `MaterialApp.router`

```dart
// 📄 lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/settings/theme_mode_controller.dart';
import 'features/cart/data/cart_sync_service.dart';
import 'router/app_router.dart';

class TokoKuApp extends ConsumerWidget {
  const TokoKuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.watch(cartSyncServiceProvider); // aktifkan auto-sync saat online
    final themeMode = ref.watch(themeModeControllerProvider).value;
    return MaterialApp.router(
      title: 'TokoKu Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: .dark),
      themeMode: themeMode ?? .system,
      routerConfig: router,
    );
  }
}
```

✅ **Checklist Lab 2B:**

- [ ] Belum login → `/login`; setelah login → `/products`
- [ ] App **tertutup**, `adb ... tokoku://app/products/5` → setelah splash langsung ke detail produk 5 (bukan katalog)
- [ ] Belum login + deep link `/cart` → login → mendarat di `/cart`
- [ ] Bottom nav 3 tab; posisi scroll katalog **tetap** saat pindah tab
- [ ] Pencarian: ketik cepat "phone" → hanya **1** request di log
- [ ] `flutter test test/unit/auth_redirect_test.dart` lulus

---

## 🧠 Kuis Harian

1. Jelaskan mengapa `QueuedInterceptor` **saja** tidak mencegah refresh berganda. Apa tambahan yang diperlukan?
2. Mengapa error jaringan saat refresh tidak boleh menghapus token?
3. Kenapa `.env` sebagai asset tidak aman, padahal file `.env` tidak di-commit ke Git?
4. Apa risiko certificate pinning jika tim lupa merencanakan rotasi sertifikat?
5. Mengapa `authRedirect` dibuat sebagai fungsi murni di luar `GoRouter`?

## 🏠 Tugas Rumah (PR)

1. **RetryInterceptor**: ulangi otomatis maks. 2× untuk `connectionTimeout`/`receiveTimeout` dengan jeda 1s dan 2s — **hanya** untuk method idempoten (`GET`). Tulis test dengan `FakeAdapter`.
2. Migrasikan `.env*` di repo `product_list_demo` Anda ke `config/*.json`; buktikan dengan `unzip -l` bahwa tidak ada `.env` di APK.
3. (Bonus) Rute `/products/category/:slug` + halaman 404 kustom; uji dengan deep link.
