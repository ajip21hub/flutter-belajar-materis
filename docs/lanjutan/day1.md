# Hari 1 — Arsitektur Modern, Dart 3.13 & Migrasi Riverpod 3

## 🎯 Tujuan Pembelajaran

Setelah hari ini peserta dapat:

* Meng-upgrade proyek lama (Flutter 3.35 / Dart 3.9) ke **Flutter 3.47 / Dart 3.13**, termasuk migrasi ke paket **`material_ui`**.
* Memakai fitur bahasa terbaru: **dot shorthands** (3.10) dan **primary constructors** (3.13), di samping sealed class & pattern matching.
* Menyusun proyek sebagai **pub workspace** (monorepo) dengan paket murni Dart, dan menegakkan aturan Riverpod lewat **`riverpod_lint`**.
* **Memigrasikan `StateNotifier`** (pola yang dipakai di materis & `product_list_demo`) ke **Riverpod 3 + code generation**.
* Memodelkan state & error dengan **freezed 4** dan **sealed class**.
* Memakai **Dart & Flutter MCP server** agar asisten AI bisa membaca error analyzer, menjalankan test, dan hot reload.

## ⏰ Jadwal

| Waktu | Durasi | Sesi |
|---|---|---|
| 08:00 – 08:30 | 30' | Pembukaan + 📝 **pre-test diagnostik** (15 soal = soal post-test Hari 5) |
| 08:30 – 09:10 | 40' | Teori: yang berubah dari Flutter 3.35 → 3.47 & Dart 3.9 → 3.13 |
| 09:10 – 10:00 | 50' | 🧪 **Lab 1A**: upgrade `product_list_demo` + migrasi `material_ui` |
| 10:00 – 10:10 | 10' | Coffee break |
| 10:10 – 11:00 | 50' | Teori + demo: feature-first, **pub workspace**, `riverpod_lint` |
| 11:00 – 12:00 | 60' | Riverpod 3 untuk pengguna Riverpod 2 + 🧪 **Lab 1B**: migrasi `StateNotifier` |
| 12:00 – 13:00 | 60' | ISHOMA |
| 13:00 – 13:30 | 30' | freezed 4 + sealed `Failure` |
| 13:30 – 15:20 | 110' | 🧪 **Lab Capstone 1**: workspace TokoKu Pro + `tokoku_core` + katalog paginasi |
| 15:20 – 15:40 | 20' | 🤖 Demo: Dart & Flutter MCP server |
| 15:40 – 16:00 | 20' | Kuis harian, PR, preview Hari 2 |

---

## 📝 Sesi 1 — Pre-Test Diagnostik (20 menit)

Peserta mengerjakan **15 soal Post-Test di Hari 5** (tanpa kunci jawaban). Hasilnya dipakai fasilitator untuk:

* Mengetahui topik yang perlu penekanan (mis. jika banyak yang belum paham `QueuedInterceptor`, beri waktu ekstra di Hari 2).
* Mengukur peningkatan: skor post-test dibandingkan skor pre-test.

> 🔁 **Tidak ada pengulangan materi dasar.** Widget, layout, `FutureBuilder`, `provider`, form validation, repository, unit/widget test dasar, dan CI dasar sudah dipelajari di [materis](https://materis.vercel.app) dan repo `day1`–`day9`. Jika pre-test menunjukkan celah di topik dasar, fasilitator memberi rujukan halaman materis yang relevan sebagai bacaan malam.

---

## 📘 Sesi 2 — Flutter 3.35 → 3.47, Dart 3.9 → 3.13 (40 menit)

Repo latihan sebelumnya memakai `sdk: ^3.9.2` (Flutter 3.35). Dalam setahun ada banyak perubahan:

| Rilis | Perubahan yang berdampak ke kode Anda |
|---|---|
| Dart 3.10 | **Dot shorthands**: `mainAxisAlignment: .center`, `fit: .cover` |
| Dart 3.13 | **Primary constructors** stable. ⚠️ *Breaking*: `final`/`var` pada parameter biasa sekarang **error** → `dart fix --apply --code=extraneous_modifier` |
| Flutter 3.44 | Swift Package Manager jadi default iOS/macOS; CocoaPods *maintenance mode* |
| Flutter 3.47 | **`material_ui` & `cupertino_ui` 1.0** (Material/Cupertino lepas dari SDK), Widget Previews stable, Impeller default di desktop, AGP 9 / Kotlin 2.4 / minSdk 24 / targetSdk 36 |
| Flutter 3.50 (Nov 2026) | Material/Cupertino bawaan SDK dijadwalkan **deprecated** → kode lama memunculkan *info* deprecation; CI dengan `--fatal-infos` akan gagal |
| Riverpod 3 (2025) | `StateNotifier`/`ChangeNotifierProvider`/`StateProvider` dipindah ke `legacy.dart`; codegen memakai `Ref` tunggal |
| go_router | Status resmi **feature-complete** (maintenance mode): stabil, hanya perbaikan bug |

### Fitur bahasa yang akan dipakai sepanjang pelatihan

```dart
// 📄 lib/warmup/dart3_demo.dart
// ignore_for_file: avoid_print
// Dart 3.0 -> 3.13: fitur yang dipakai sepanjang pelatihan.

// 1) PRIMARY CONSTRUCTORS (stable Dart 3.13).
//    Sebelumnya:
//      final class Paid extends PaymentStatus {
//        const Paid(this.amount);
//        final double amount;
//      }
//    Sekarang field + konstruktor cukup di header class:
sealed class PaymentStatus {
  const PaymentStatus();
}

final class const Paid(final double amount) extends PaymentStatus;

final class const Pending() extends PaymentStatus;

final class const Failed(final String reason, {final bool retryable = false})
    extends PaymentStatus;

// 2) SEALED + SWITCH EXPRESSION exhaustive (Dart 3.0).
String describe(PaymentStatus s) => switch (s) {
  Paid(:final amount) when amount > 100 => 'Lunas (besar): \$$amount',
  Paid(:final amount) => 'Lunas: \$$amount',
  Pending() => 'Menunggu pembayaran',
  Failed(:final reason, retryable: true) => 'Gagal ($reason), coba lagi',
  Failed(:final reason) => 'Gagal: $reason',
  // Tidak perlu `default`: compiler tahu semua subtype sudah ditangani.
};

// 3) DOT SHORTHANDS (Dart 3.10): nama tipe boleh dihilangkan bila konteks
//    tipenya sudah jelas -> `.pending` bukan `Priority.pending`.
enum Priority { low, normal, high }

Priority parsePriority(String raw) => switch (raw) {
  'urgent' => .high,
  'later' => .low,
  _ => .normal,
};

// 4) RECORDS + destructuring (Dart 3.0).
(int count, double total) summarize(List<double> prices) =>
    (prices.length, prices.fold(0.0, (a, b) => a + b));

// 5) PATTERN MATCHING pada JSON: aman tanpa cast manual.
String? cityFromJson(Map<String, dynamic> json) {
  if (json case {'address': {'city': final String city}}) return city;
  return null;
}

void main() {
  final (count, total) = summarize([10, 20.5]);
  print('$count item, total $total');
  print(describe(const Paid(150)));
  print(describe(const Failed('timeout', retryable: true)));
  print(parsePriority('urgent'));
  print(
    cityFromJson({
      'address': {'city': 'Yogyakarta'},
    }),
  );
}
```

> 💡 **Kapan primary constructor, kapan freezed?** Primary constructor menghapus *boilerplate* field + konstruktor. freezed tetap dibutuhkan bila Anda butuh `copyWith`, `==`/`hashCode` otomatis untuk banyak field, union, dan `fromJson/toJson`. Untuk value object kecil (mis. `Money`), primary constructor + `==` manual sudah cukup.

---

## 🧪 Lab 1A — Upgrade Proyek Lama (50 menit)

Gunakan `product_list_demo` milik Anda (Flutter 3.35, Provider + Riverpod 2). Ini simulasi tugas nyata: **meng-upgrade app yang sudah di-production**.

```bash
cd product_list_demo
git checkout -b chore/upgrade-flutter-3.47

# 1. Naikkan constraint SDK di pubspec.yaml -> sdk: ^3.13.0
flutter pub upgrade --major-versions

# 2. Perbaiki otomatis perubahan bahasa & API (termasuk extraneous_modifier)
dart fix --dry-run      # lihat dulu apa yang akan diubah
dart fix --apply

# 3. Migrasi ke paket Material terpisah
flutter pub add material_ui
dart fix --apply --code=migrate_design_widgets

# 4. Riverpod 3: StateNotifier masih bisa dipakai lewat legacy import
#    import 'package:flutter_riverpod/legacy.dart';

flutter analyze
flutter test
flutter build apk --debug   # memaksa Gradle/AGP ikut di-upgrade
```

| Gejala | Penyebab | Solusi |
|---|---|---|
| `Can't have modifier 'final' here` | Dart 3.13 mencadangkan `final` untuk primary constructor | `dart fix --apply --code=extraneous_modifier` |
| `StateNotifierProvider isn't defined` | Riverpod 3 memindahkan API lama | `import 'package:flutter_riverpod/legacy.dart'` (sementara), lalu migrasi di Lab 1B |
| Gradle: AGP/Kotlin terlalu lama | Flutter 3.47 diverifikasi dengan AGP 9.1, KGP 2.4, Gradle 9.3 | Ikuti pesan `flutter build`, perbarui `settings.gradle.kts` |
| Info deprecation `package:flutter/material.dart` | Material sudah dipisah | Langkah 3 di atas |

✅ **Checklist Lab 1A:** `flutter analyze` bersih, test lama tetap lulus, APK debug ter-build, PR dibuat dengan judul `chore: upgrade Flutter 3.47`.

---

## 📘 Sesi 3 — Feature-First, Pub Workspace & riverpod_lint (50 menit)

### 3.1 Dari MVVM / layer-first ke feature-first

| Yang sudah Anda kenal | Padanan di TokoKu Pro |
|---|---|
| `day6`: `ViewModel extends ChangeNotifier` | `Notifier`/`AsyncNotifier` (controller) di `features/<fitur>/presentation/` |
| `day6`: `services/api_service.dart` | `features/<fitur>/data/*_remote_data_source.dart` |
| `product_list_demo`: `data/repositories/` di root | `features/<fitur>/data/*_repository.dart` |
| `product_list_demo`: `core/types/result.dart` | `sealed class Failure` + `AsyncValue` (Sesi 5) |

```
lib/
 ┣ core/                  # dipakai lintas fitur: config, network, database, error
 ┣ features/
 ┃ ┣ products/ { data/, domain/, presentation/ }
 ┃ ┣ cart/  auth/  orders/  ai/ ...
 ┗ router/
```

**Aturan dependensi:** `presentation → data → domain`. Domain tidak meng-import Flutter UI/Dio. Fitur boleh memakai `core/`, tetapi `core/` **tidak boleh** meng-import fitur (lihat cara memutus siklus dengan `session_events.dart` di Hari 2).

### 3.2 Pub workspace: monorepo resmi Dart

Saat app membesar, sebagian kode layak menjadi **paket terpisah**: value object, design system, SDK API internal. Pub workspace (Dart ≥ 3.6) membuat beberapa paket dalam satu repo berbagi **satu** `pubspec.lock` & satu resolusi dependensi.

```yaml
# capstone/pubspec.yaml (root workspace sekaligus app)
environment:
  sdk: ^3.13.0

workspace:
  - packages/tokoku_core

dependencies:
  tokoku_core: ^1.0.0   # di-resolve ke folder lokal
```

```yaml
# 📄 packages/tokoku_core/pubspec.yaml
name: tokoku_core
description: Value object & utilitas murni Dart yang dipakai lintas fitur TokoKu Pro.
version: 1.0.0
publish_to: none

environment:
  sdk: ^3.13.0

# Anggota pub workspace (lihat pubspec.yaml di root capstone).
resolution: workspace

# lib/ TIDAK boleh meng-import Flutter. Untuk test kita tetap memakai
# flutter_test karena satu workspace = satu resolusi dependensi, dan versi
# `package:test` terbaru bentrok dengan versi yang dipin oleh flutter_test.
dev_dependencies:
  flutter_test:
    sdk: flutter
```

Keuntungan paket murni Dart (`lib/` `tokoku_core` tidak meng-import Flutter):

* Bisa dipakai ulang di backend/CLI Dart, test-nya cepat dan terisolasi.
* **Batas arsitektur dipaksa compiler**: `tokoku_core` mustahil meng-import widget atau fitur app.

> ⚠️ **Pelajaran nyata dari pembuatan materi ini:** satu workspace = **satu** resolusi dependensi. `package:test` versi terbaru membutuhkan `test_api` yang lebih baru daripada yang **dipin** oleh `flutter_test` di SDK → `pub get` gagal (*version solving failed*). Solusinya: paket murni Dart di workspace Flutter memakai `flutter_test` sebagai **dev dependency** dan dijalankan dengan `flutter test`. Kode di `lib/` tetap bebas Flutter.

```dart
// 📄 packages/tokoku_core/lib/src/money.dart
/// Mata uang yang didukung. Enum dengan *primary constructor* (Dart 3.13):
/// field `symbol`, `decimals`, dst. dideklarasikan langsung di header.
enum Currency(
  final String symbol,
  final int decimals,
  final String thousandSep,
  final String decimalSep,
) {
  usd(r'$', 2, ',', '.'),
  idr('Rp', 0, '.', ','),
}

/// Nilai uang dalam satuan terkecil (sen/rupiah) memakai `int`.
///
/// Kenapa bukan `double`? `0.1 + 0.2 == 0.30000000000000004`. Untuk total
/// keranjang & pembayaran, galat pembulatan seperti itu adalah bug.
///
/// `class const Money(...)` = primary constructor konstan (Dart 3.13):
/// field `minorUnits` & `currency` + konstruktor ditulis dalam satu baris.
class const Money(final int minorUnits, final Currency currency) {
  /// Konversi dari nilai desimal API (mis. `12.99`) -> `1299` sen.
  factory Money.fromDecimal(num amount, Currency currency) =>
      Money((amount * _scale(currency)).round(), currency);

  factory Money.zero(Currency currency) => Money(0, currency);

  Money operator +(Money other) {
    _checkSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currency);
  }

  Money operator *(int factor) => Money(minorUnits * factor, currency);

  bool get isZero => minorUnits == 0;

  /// `$1,299.99` atau `Rp 125.000`.
  String format() {
    final scale = _scale(currency);
    final negative = minorUnits < 0;
    final abs = minorUnits.abs();
    final whole = _group((abs ~/ scale).toString(), currency.thousandSep);
    final frac = currency.decimals == 0
        ? ''
        : '${currency.decimalSep}'
              '${(abs % scale).toString().padLeft(currency.decimals, '0')}';
    final sep = currency == .idr ? ' ' : '';
    return '${negative ? '-' : ''}${currency.symbol}$sep$whole$frac';
  }

  void _checkSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError(
        'Tidak bisa menjumlah ${other.currency} ke $currency',
      );
    }
  }

  static int _scale(Currency c) {
    var s = 1;
    for (var i = 0; i < c.decimals; i++) {
      s *= 10;
    }
    return s;
  }

  static String _group(String digits, String sep) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(sep);
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => format();
}
```

```dart
// 📄 packages/tokoku_core/test/money_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tokoku_core/tokoku_core.dart';

void main() {
  test('fromDecimal menghindari galat floating point', () {
    final total = Money.fromDecimal(0.1, .usd) + Money.fromDecimal(0.2, .usd);
    expect(total, Money.fromDecimal(0.3, .usd));
  });

  test('format USD dengan pemisah ribuan', () {
    expect(Money.fromDecimal(1299.99, .usd).format(), r'$1,299.99');
    expect(Money.fromDecimal(7.5, .usd).format(), r'$7.50');
  });

  test('format Rupiah tanpa desimal', () {
    expect(const Money(125000, .idr).format(), 'Rp 125.000');
  });

  test('perkalian qty & penjumlahan', () {
    final subtotal = Money.fromDecimal(9.99, .usd) * 3;
    expect(subtotal.format(), r'$29.97');
  });

  test('beda mata uang -> ArgumentError', () {
    expect(
      () => Money.zero(.usd) + Money.zero(.idr),
      throwsA(isA<ArgumentError>()),
    );
  });
}
```

### 3.3 riverpod_lint — aturan dipaksa analyzer

`riverpod_lint` 3 berjalan sebagai **analyzer plugin** resmi (bukan `custom_lint` lagi). Pasang di `analysis_options.yaml`:

```yaml
# 📄 analysis_options.yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - build/**
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - android/**
    - ios/**
    - web/**
  language:
    strict-casts: true
    strict-raw-types: true

# riverpod_lint 3 = analyzer plugin resmi (analysis_server_plugin), bukan
# custom_lint. Berjalan otomatis di IDE, `dart analyze`, dan `flutter analyze`.
plugins:
  riverpod_lint: ^3.2.0

linter:
  rules:
    - prefer_const_constructors
    - unawaited_futures
    - avoid_print
```

Contoh yang ditangkap: lupa `part '...g.dart'`, memanggil `ref.watch` di dalam callback `onPressed`, provider `keepAlive` yang bergantung pada provider `autoDispose`, notifier dengan konstruktor berparameter.

---

## 📘 Sesi 4 — Riverpod 3 untuk Pengguna Riverpod 2 (30 menit)

Di `product_list_demo` & materis Anda sudah memakai `StateNotifierProvider`, `FutureProvider.family`, `AsyncNotifier` manual, dan `ref.listen`. Yang berubah:

| Riverpod 2 (materi lama) | Riverpod 3 + codegen |
|---|---|
| `StateNotifier`, `StateNotifierProvider`, `StateProvider`, `ChangeNotifierProvider` | **Legacy** → `@riverpod class X extends _$X` (`Notifier`/`AsyncNotifier`) |
| `FutureProvider.family<T, Arg>(...)` | Fungsi `@riverpod Future<T> x(Ref ref, Arg arg)` — family otomatis |
| `FooRef ref` | Cukup `Ref ref` |
| `AsyncValue.valueOrNull` | `.value` (null jika belum ada data) |
| Provider error = langsung gagal | **Auto-retry** dengan backoff (atur via `retry:`) |
| Cek `mounted` manual setelah `await` | `ref.mounted` |
| `ProviderContainer()` + `addTearDown(dispose)` | `ProviderContainer.test()` |
| — | Provider di widget yang tidak terlihat **di-pause** (mis. tab lain `StatefulShellRoute`) |
| — | *Eksperimental*: **Mutations** & **offline persistence** (Hari 3) |

### `autoDispose` vs `keepAlive`

* `@riverpod` = **autoDispose**: state dibuang saat tak ada listener → layar detail, pencarian.
* `@Riverpod(keepAlive: true)` → hidup selama app: `Dio`, database, repository, status auth, router.

---

## 🧪 Lab 1B — Migrasi `StateNotifier` → `Notifier` (30 menit)

Di materis (`implementasi/multi-language`) bahasa dikelola seperti ini:

```dart
// SEBELUM — materis/implementasi/multi-language.md
class LanguageNotifier extends StateNotifier<LanguageState> {
  LanguageNotifier() : super(LanguageState(language: 'en', locale: const Locale('en'))) {
    _loadSavedLanguage();       // async di konstruktor, state awal "palsu"
  }
  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    ...
  }
}
final languageProvider = StateNotifierProvider<LanguageNotifier, LanguageState>(
  (ref) => LanguageNotifier(),
);
```

Masalah versi lama: state awal sempat `en` sebelum nilai tersimpan terbaca (UI berkedip), tidak ada status loading/error, dan sulit di-test karena `SharedPreferences.getInstance()` dipanggil langsung.

```dart
// 📄 lib/warmup/language_controller.dart
// Hasil migrasi `LanguageNotifier extends StateNotifier` dari materi
// materis (implementasi/multi-language) ke Riverpod 3 + codegen.
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'language_controller.g.dart';

/// State immutable dengan primary constructor (Dart 3.13).
class const LanguageState(final Locale locale) {
  String get code => locale.languageCode;
}

/// SEBELUM (Riverpod 2, legacy di Riverpod 3):
/// ```dart
/// class LanguageNotifier extends StateNotifier<LanguageState> { ... }
/// final languageProvider =
///     StateNotifierProvider<LanguageNotifier, LanguageState>(...);
/// ```
///
/// SESUDAH: satu class beranotasi, provider `languageControllerProvider`
/// di-generate. Load awal dari storage jadi bagian `build()` yang async,
/// sehingga UI otomatis mendapat AsyncLoading/AsyncData — tidak perlu flag
/// `isLoading` manual seperti versi lama.
@Riverpod(keepAlive: true)
class LanguageController extends _$LanguageController {
  static const _key = 'language_code';
  static const supported = [Locale('id'), Locale('en')];

  final _prefs = SharedPreferencesAsync();

  @override
  Future<LanguageState> build() async {
    final saved = await _prefs.getString(_key);
    return LanguageState(Locale(saved ?? 'id'));
  }

  Future<void> change(Locale locale) async {
    if (!supported.contains(locale)) return;
    state = AsyncData(LanguageState(locale)); // optimistic update
    await _prefs.setString(_key, locale.languageCode);
  }
}

/// Derived provider: setara `currentLocaleProvider` versi lama.
@riverpod
Locale currentLocale(Ref ref) =>
    ref.watch(languageControllerProvider).value?.locale ?? const Locale('id');
```

Test-nya — perhatikan `ProviderContainer.test()` dan plugin in-memory:

```dart
// 📄 test/unit/language_controller_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tokoku_pro/warmup/language_controller.dart';

void main() {
  // Ganti plugin SharedPreferences dengan versi in-memory (tanpa device).
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('default bahasa Indonesia, lalu tersimpan setelah diganti', () async {
    final c1 = ProviderContainer.test();
    expect((await c1.read(languageControllerProvider.future)).code, 'id');

    await c1
        .read(languageControllerProvider.notifier)
        .change(const Locale('en'));
    expect(c1.read(currentLocaleProvider), const Locale('en'));

    // Container baru = app dibuka ulang -> nilai dibaca dari storage.
    final c2 = ProviderContainer.test();
    expect((await c2.read(languageControllerProvider.future)).code, 'en');
  });

  test('locale yang tidak didukung diabaikan', () async {
    final c = ProviderContainer.test();
    await c.read(languageControllerProvider.future);
    await c
        .read(languageControllerProvider.notifier)
        .change(const Locale('fr'));
    expect(c.read(currentLocaleProvider), const Locale('id'));
  });
}
```

✅ **Checklist Lab 1B:** migrasikan **satu** `StateNotifier` di `product_list_demo` (mis. `CartNotifier` atau `WishlistNotifier`) dengan pola yang sama + 1 test.

---

## 📘 Sesi 5 — freezed 4 & Error Bertipe (30 menit)

Anda sudah memakai `json_serializable` (`day9`). freezed menambahkan `copyWith`, `==`, `toString`, dan **union**:

```dart
// 📄 lib/features/products/domain/product.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'product.freezed.dart';
part 'product.g.dart';

@freezed
abstract class Product with _$Product {
  const factory Product({
    required int id,
    required String title,
    @Default('') String description,
    @Default('') String category,
    required double price,
    @Default(0) double rating,
    @Default(0) int stock,
    @Default('') String thumbnail,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
}

/// Satu halaman hasil paginasi dari API.
@freezed
abstract class ProductPage with _$ProductPage {
  const factory ProductPage({
    required List<Product> items,
    required int total,
    @Default(false) bool fromCache,
  }) = _ProductPage;
}
```

> ⚠️ Sejak **freezed 3**, class wajib `abstract` (atau `sealed` untuk union). Gunakan `switch` pattern matching sebagai pengganti `.when()`/`.map()` lama.

Pengganti `Result<T>` di `product_list_demo`: **sealed `Failure`** yang dilempar repository dan ditangkap `AsyncValue`:

```dart
// 📄 lib/core/error/failure.dart
import 'package:dio/dio.dart';

/// Hierarki error domain. `sealed` memaksa UI menangani semua kasus
/// lewat `switch` yang exhaustive.
sealed class Failure implements Exception {
  const Failure(this.message);
  final String message;

  @override
  String toString() => message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Tidak ada koneksi internet']);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([
    super.message = 'Sesi berakhir, silakan login lagi',
  ]);
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});
  final int? statusCode;
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Terjadi kesalahan tak terduga']);
}

/// Mengubah DioException menjadi Failure yang ramah domain.
Failure mapDioError(Object error) {
  if (error is Failure) return error;
  if (error is! DioException) return const UnknownFailure();
  return switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => const NetworkFailure(),
    DioExceptionType.badResponse when error.response?.statusCode == 401 =>
      const UnauthorizedFailure(),
    DioExceptionType.badResponse => ServerFailure(
      (error.response?.data is Map
              ? (error.response!.data as Map)['message']?.toString()
              : null) ??
          'Server error',
      statusCode: error.response?.statusCode,
    ),
    _ => const UnknownFailure(),
  };
}
```

| `Result<T>` (lama) | `AsyncValue<T>` + `sealed Failure` |
|---|---|
| Setiap pemanggil wajib `if (result.isSuccess)` | Repository melempar `Failure`, Riverpod membungkus jadi `AsyncError` |
| Loading dikelola terpisah | Loading/data/error dalam satu tipe |
| Jenis error berupa string/enum | `switch` exhaustive atas subtype `Failure` |

---

## 🧪 Lab Capstone 1 — Workspace TokoKu Pro + Katalog (110 menit)

### Langkah 1 — Buat proyek dari starter

```bash
git clone <starter-repo-dari-fasilitator> tokoku_pro && cd tokoku_pro
# Starter sudah berisi: pubspec (semua paket 5 hari), analysis_options,
# struktur folder, UI login & tema. Anda menulis bagian "advanced"-nya.
mkdir -p packages/tokoku_core/{lib/src,test}
```

Isi `packages/tokoku_core` dengan `pubspec.yaml`, `money.dart`, dan `money_test.dart` dari Sesi 3, lalu:

```bash
flutter pub get            # resolusi SATU kali untuk seluruh workspace
(cd packages/tokoku_core && flutter test)
```

### Langkah 2 — Remote data source (Dio)

```dart
// 📄 lib/features/products/data/product_remote_data_source.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../domain/product.dart';

part 'product_remote_data_source.g.dart';

class ProductRemoteDataSource {
  ProductRemoteDataSource(this._dio);
  final Dio _dio;

  static const _fields =
      'title,description,category,price,rating,stock,thumbnail';

  Future<ProductPage> fetchPage({
    required int limit,
    required int skip,
    CancelToken? cancelToken,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/products',
      queryParameters: {'limit': limit, 'skip': skip, 'select': _fields},
      cancelToken: cancelToken,
    );
    return _toPage(res.data!);
  }

  Future<ProductPage> search(String query, {CancelToken? cancelToken}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/products/search',
      queryParameters: {'q': query, 'select': _fields},
      cancelToken: cancelToken,
    );
    return _toPage(res.data!);
  }

  Future<Product> fetchDetail(int id) async {
    final res = await _dio.get<Map<String, dynamic>>('/products/$id');
    return Product.fromJson(res.data!);
  }

  ProductPage _toPage(Map<String, dynamic> json) => ProductPage(
    items: (json['products'] as List)
        .cast<Map<String, dynamic>>()
        .map(Product.fromJson)
        .toList(),
    total: json['total'] as int,
  );
}

@Riverpod(keepAlive: true)
ProductRemoteDataSource productRemoteDataSource(Ref ref) =>
    ProductRemoteDataSource(ref.watch(dioProvider));
```

### Langkah 3 — Repository (versi Hari 1: remote saja)

```dart
// lib/features/products/data/product_repository.dart (versi Hari 1)
class ProductRepository {
  ProductRepository(this._remote);
  final ProductRemoteDataSource _remote;

  Future<ProductPage> getPage({required int limit, required int skip, CancelToken? cancelToken}) async {
    try {
      return await _remote.fetchPage(limit: limit, skip: skip, cancelToken: cancelToken);
    } catch (e) {
      throw mapDioError(e); // DioException -> Failure
    }
  }
}

@Riverpod(keepAlive: true)
ProductRepository productRepository(Ref ref) =>
    ProductRepository(ref.watch(productRemoteDataSourceProvider));
```

> Hari 3 kita menambahkan database lokal ke repository ini **tanpa mengubah UI sama sekali**.

### Langkah 4 — Controller paginasi (AsyncNotifier + freezed state)

```dart
// 📄 lib/features/products/presentation/product_list_controller.dart
import 'package:dio/dio.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/product_repository.dart';
import '../domain/product.dart';

part 'product_list_controller.freezed.dart';
part 'product_list_controller.g.dart';

@freezed
abstract class ProductListState with _$ProductListState {
  const ProductListState._();
  const factory ProductListState({
    @Default([]) List<Product> items,
    @Default(0) int total,
    @Default(false) bool isLoadingMore,
    @Default(false) bool fromCache,
  }) = _ProductListState;

  bool get hasMore => items.length < total;
}

@riverpod
class ProductListController extends _$ProductListController {
  static const pageSize = 20;

  @override
  Future<ProductListState> build() async {
    final cancelToken = CancelToken();
    ref.onDispose(cancelToken.cancel); // batalkan request jika provider dibuang
    final page = await ref
        .watch(productRepositoryProvider)
        .getPage(limit: pageSize, skip: 0, cancelToken: cancelToken);
    return ProductListState(
      items: page.items,
      total: page.total,
      fromCache: page.fromCache,
    );
  }

  /// Infinite scroll: dipanggil saat user mendekati akhir list.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref
          .read(productRepositoryProvider)
          .getPage(limit: pageSize, skip: current.items.length);
      if (!ref.mounted) return; // Riverpod 3: cek provider masih hidup
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          total: page.total,
          isLoadingMore: false,
          fromCache: page.fromCache,
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      // Jangan buang data lama; cukup hentikan indikator loading.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  /// Pull-to-refresh.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Detail produk per-id (family). autoDispose default di codegen.
@riverpod
Future<Product> productDetail(Ref ref, int id) =>
    ref.watch(productRepositoryProvider).detail(id);
```

Hal baru dibanding `ProductsNotifier` di `product_list_demo`:

* `ref.onDispose(cancelToken.cancel)` — request dibatalkan bila layar ditutup.
* `ref.mounted` setelah `await` — tidak menulis state ke provider yang sudah dibuang.
* `loadMore()` tidak membuang data lama saat gagal.

### Langkah 5 — Halaman katalog (dot shorthands + `Money`)

```dart
// 📄 lib/features/products/presentation/product_list_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tokoku_core/tokoku_core.dart';

import '../../../core/error/failure.dart';
import '../domain/product.dart';
import 'product_list_controller.dart';

class ProductListPage extends ConsumerWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(productListControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog'),
        actions: [
          IconButton(
            tooltip: 'Cari',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/products/search'),
          ),
        ],
      ),
      body: switch (asyncState) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () =>
              ref.read(productListControllerProvider.notifier).refresh(),
          child: _ProductGrid(state: value),
        ),
        AsyncError(:final error) => _ErrorView(
          message: error is Failure ? error.message : '$error',
          onRetry: () => ref.invalidate(productListControllerProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ProductGrid extends ConsumerWidget {
  const _ProductGrid({required this.state});
  final ProductListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 400) {
          ref.read(productListControllerProvider.notifier).loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (state.fromCache)
            const SliverToBoxAdapter(
              child: MaterialBanner(
                content: Text('Mode offline — menampilkan data tersimpan'),
                leading: Icon(Icons.cloud_off),
                actions: [SizedBox.shrink()],
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemCount: state.items.length,
              itemBuilder: (context, i) => ProductCard(product: state.items[i]),
            ),
          ),
          if (state.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/products/${product.id}'),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Expanded(
              child: Hero(
                tag: 'product-${product.id}',
                child: product.thumbnail.isEmpty
                    ? const ColoredBox(
                        color: Colors.black12,
                        child: Icon(Icons.image),
                      )
                    : CachedNetworkImage(
                        imageUrl: product.thumbnail,
                        fit: .cover,
                        memCacheWidth:
                            400, // decode sesuai ukuran tampil -> hemat RAM
                        placeholder: (_, _) =>
                            const ColoredBox(color: Colors.black12),
                        errorWidget: (_, _, _) =>
                            const Icon(Icons.broken_image),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: .ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Money.fromDecimal(product.price, .usd).format(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: .min,
      children: [
        const Icon(Icons.error_outline, size: 48),
        const SizedBox(height: 8),
        Text(message, textAlign: .center),
        const SizedBox(height: 8),
        FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    ),
  );
}
```

> Untuk Hari 1, jalankan dengan `home: const ProductListPage()` di dalam `ProviderScope`. `context.push(...)` baru berfungsi setelah router dipasang di Hari 2.

### Langkah 6 — Jalankan

```bash
dart run build_runner watch   # biarkan berjalan selama lab
flutter run --flavor dev --dart-define-from-file=config/dev.json
```

> `--flavor dev` wajib karena starter sudah memiliki `productFlavors` (dibahas di Hari 5).

✅ **Checklist Lab:**

- [ ] `flutter test` di `packages/tokoku_core` lulus
- [ ] Grid produk tampil, harga diformat `Money` (`$1,299.99`)
- [ ] Infinite scroll memuat 20 produk berikutnya, pull-to-refresh berfungsi
- [ ] Mode pesawat → `NetworkFailure` "Tidak ada koneksi internet" + tombol **Coba lagi**
- [ ] `flutter analyze` (termasuk riverpod_lint) → *No issues found*

---

## 🤖 Sesi 6 — AI-Assisted Development dengan MCP (20 menit)

Tim Flutter merilis **Dart & Flutter MCP server**: asisten AI (Claude Code, Gemini CLI, Cursor, Antigravity, dll.) dapat membaca error analyzer, mencari simbol, menjalankan test, bahkan **hot reload** app yang sedang berjalan.

```bash
# Contoh: Claude Code — plugin resmi (skills Flutter/Dart + MCP server)
claude plugin marketplace add flutter/agent-plugins
claude plugin install dart-flutter@dart-flutter

# Hanya MCP server (berlaku untuk klien MCP mana pun)
dart mcp-server
```

Demo: minta asisten "jalankan `flutter analyze`, perbaiki semua info riverpod_lint, lalu jalankan test". Diskusikan:

* AI cocok untuk *boilerplate* & tugas berulang; **arsitektur & keputusan desain tetap di tangan Anda**.
* Selalu baca diff sebelum menerima perubahan; test adalah jaring pengaman.
* Jangan menempelkan secret/kredensial ke prompt.

---

## 🧠 Kuis Harian

1. Apa yang terjadi pada `void f(final int x)` setelah upgrade ke Dart 3.13, dan bagaimana memperbaikinya?
2. Tulis ulang `class Point { const Point(this.x, this.y); final int x; final int y; }` dengan primary constructor.
3. Apa keuntungan meletakkan `Money` di paket workspace terpisah dibanding di `lib/core/`?
4. Sebutkan 3 perbedaan `StateNotifier` (materis) dengan `@riverpod class ... extends _$...`.
5. Mengapa `loadMore()` memeriksa `ref.mounted` setelah `await`?

## 🏠 Tugas Rumah (PR)

1. Selesaikan migrasi **semua** `StateNotifier` di `product_list_demo` ke codegen (+ test masing-masing).
2. Tambahkan toggle mata uang USD/IDR di AppBar katalog: konversi dengan kurs tetap (konstanta di `tokoku_core`, + unit test), simpan pilihan memakai pola `LanguageController`.
3. Pastikan CI repo Anda menjalankan test `packages/tokoku_core` dan `flutter analyze --fatal-infos`.
