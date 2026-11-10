# Hari 3 — Offline-First, Background Sync & Real-time

## 🎯 Tujuan Pembelajaran

* Mendesain tabel, query, dan **stream reaktif** dengan **drift**, termasuk **migrasi skema** yang teruji.
* Menerapkan **network-first + fallback cache** di repository tanpa mengubah UI.
* Membangun **outbox sync** yang tahan *race condition* (data berubah saat request berjalan).
* Menjalankan sinkronisasi **di background walau app ditutup** dengan **workmanager** (isolate terpisah + `ProviderContainer`).
* Membangun fitur **real-time dengan WebSocket**: reconnect otomatis dengan *exponential backoff*, penutupan koneksi via autoDispose.
* Mengenal **offline persistence Riverpod 3** (eksperimental) dan kapan memakainya.

> Materi lama hanya menyebut `sqflite`/`connectivity_plus` di *case study* dan menandai "offline support" sebagai *coming soon*. Hari ini semuanya diimplementasikan.

## ⏰ Jadwal

| Waktu | Durasi | Sesi |
|---|---|---|
| 08:00 – 08:15 | 15' | Review PR Hari 2 |
| 08:15 – 08:35 | 20' | Offline-first: memilih storage & strategi cache |
| 08:35 – 09:20 | 45' | drift: tabel, stream, row class, migrasi |
| 09:20 – 10:00 | 40' | 🧪 **Lab 3A**: cache katalog offline |
| 10:00 – 10:10 | 10' | Coffee break |
| 10:10 – 10:50 | 40' | Outbox pattern, konflik & race condition |
| 10:50 – 12:00 | 70' | 🧪 **Lab 3B**: keranjang offline + sync |
| 12:00 – 13:00 | 60' | ISHOMA |
| 13:00 – 13:40 | 40' | Background work: isolate, workmanager, batasan Android |
| 13:40 – 14:00 | 20' | Real-time: polling vs SSE vs WebSocket |
| 14:00 – 15:30 | 90' | 🧪 **Lab 3C**: background sync + status pesanan live |
| 15:30 – 15:45 | 15' | Kuis harian |
| 15:45 – 16:00 | 15' | Rangkuman & PR |

---

## 📘 Sesi 1 — Memilih Storage & Strategi Cache (20 menit)

| Kebutuhan | Pilihan | Catatan |
|---|---|---|
| Token, kredensial | `flutter_secure_storage` | Sudah dipakai sejak `day4` |
| Preferensi kecil | **`SharedPreferencesAsync`** | API async; pengganti `SharedPreferences.getInstance()` di materi lama |
| Data relasional, query, paging | **drift** (SQLite, type-safe, reactive) | Dipakai di capstone |
| Key-value cepat | `hive_ce` | Fork komunitas (`hive` asli tidak dirilis sejak 2022) |
| NoSQL embedded | `isar_community` | Fork komunitas (`isar` asli berhenti di 3.1.0, 2023) |
| Sync ke backend siap pakai | PowerSync, `syncable` (drift + Supabase) | Bacaan lanjutan |

| Strategi | Alur | Cocok untuk |
|---|---|---|
| **Network-first** (capstone) | API → simpan cache; gagal jaringan → cache | Katalog yang harus segar |
| Cache-first | Cache → API hanya jika kosong/kedaluwarsa | Data jarang berubah |
| Stale-while-revalidate | Cache segera, refresh di belakang | Feed/beranda (PR) |

---

## 📘 Sesi 2 — drift (45 menit)

```dart
// 📄 lib/core/database/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/cart/domain/cart_line.dart';

part 'app_database.g.dart';

/// Cache katalog (offline-first). Disimpan sebagai kolom terstruktur.
class CachedProducts extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get category => text()();
  RealColumn get price => real()();
  RealColumn get rating => real()();
  IntColumn get stock => integer()();
  TextColumn get thumbnail => text()();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Keranjang belanja lokal — tetap bisa dipakai saat offline.
@UseRowClass(CartLine)
class CartItems extends Table {
  IntColumn get productId => integer()();
  TextColumn get title => text()();
  RealColumn get price => real()();
  TextColumn get thumbnail => text()();
  IntColumn get qty => integer().withDefault(const Constant(1))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {productId};
}

@DriftDatabase(tables: [CachedProducts, CartItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'tokoku',
              // Background sync (workmanager) berjalan di isolate lain ->
              // izinkan beberapa isolate memakai file DB yang sama dengan aman.
              native: const DriftNativeOptions(shareAcrossIsolates: true),
            ),
      );

  @override
  int get schemaVersion => 1;

  // ---------- Produk ----------
  Future<void> upsertProducts(List<CachedProductsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(cachedProducts, rows));

  Future<List<CachedProduct>> productsPage({
    required int limit,
    required int offset,
  }) =>
      (select(cachedProducts)
            ..orderBy([(t) => OrderingTerm.asc(t.id)])
            ..limit(limit, offset: offset))
          .get();

  // ---------- Keranjang ----------
  Stream<List<CartLine>> watchCart() => select(cartItems).watch();

  Future<void> addToCart(CartItemsCompanion item) async {
    final existing =
        await (select(cartItems)
              ..where((t) => t.productId.equals(item.productId.value)))
            .getSingleOrNull();
    if (existing == null) {
      await into(cartItems).insert(item);
    } else {
      await (update(
        cartItems,
      )..where((t) => t.productId.equals(existing.productId))).write(
        CartItemsCompanion(
          qty: Value(existing.qty + 1),
          synced: const Value(false),
        ),
      );
    }
  }

  Future<void> removeFromCart(int productId) =>
      (delete(cartItems)..where((t) => t.productId.equals(productId))).go();

  Future<List<CartLine>> unsyncedCart() =>
      (select(cartItems)..where((t) => t.synced.equals(false))).get();

  /// Tandai tersinkron HANYA jika qty belum berubah sejak dikirim.
  /// Jika user menambah qty saat request sync berjalan, item tetap
  /// `synced=false` dan ikut terkirim di sync berikutnya (tidak hilang).
  Future<int> markSynced(Map<int, int> sentQtyByProductId) => transaction(
    () async {
      var updated = 0;
      for (final MapEntry(key: id, value: qty) in sentQtyByProductId.entries) {
        updated +=
            await (update(cartItems)
                  ..where((t) => t.productId.equals(id) & t.qty.equals(qty)))
                .write(const CartItemsCompanion(synced: Value(true)));
      }
      return updated;
    },
  );

  Future<void> clearCart() => delete(cartItems).go();
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
```

* `primaryKey` override → `insertAllOnConflictUpdate` menjadi *upsert*; `batch()` = banyak insert dalam satu transaksi.
* `watch()` → `Stream` yang memancarkan ulang setiap tabel berubah → cocok dengan `@riverpod Stream<...>`.
* `shareAcrossIsolates: true` → aman dibuka bersamaan oleh isolate UI dan isolate background (Sesi 4).
* `markSynced` memakai `transaction` + syarat `qty` → dibahas di Sesi 3.

### Row class kustom (`@UseRowClass`)

```dart
// 📄 lib/features/cart/domain/cart_line.dart
/// Row class kustom untuk tabel CartItems (drift `@UseRowClass`).
/// Ditulis manual agar bisa dipakai sebagai tipe return provider
/// riverpod_generator (tipe hasil generate drift tidak bisa di-resolve
/// oleh generator lain pada fase build yang sama).
class CartLine {
  const CartLine({
    required this.productId,
    required this.title,
    required this.price,
    required this.thumbnail,
    required this.qty,
    required this.synced,
  });

  final int productId;
  final String title;
  final double price;
  final String thumbnail;
  final int qty;
  final bool synced;

  double get subtotal => price * qty;
}
```

> ⚠️ **Pelajaran nyata:** `riverpod_generator` gagal (`Invalid provider type`) jika tipe return provider adalah class yang **di-generate drift**, karena kedua generator berjalan pada fase build yang sama. Row class manual menyelesaikannya — bonusnya, domain tidak bergantung pada kode generate database.

### Migrasi skema (wajib sebelum rilis kedua)

```dart
// Contoh: v2 menambah kolom `note` (nullable)
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) await m.addColumn(cartItems, cartItems.note);
      },
    );
```

```bash
# Simpan snapshot skema per versi + generate test migrasi otomatis
dart run drift_dev make-migrations
```

> Lupa menaikkan `schemaVersion` = crash `no such column` di HP pengguna lama setelah update — bug yang **tidak** muncul di HP developer yang selalu install bersih.

---

## 🧪 Lab 3A — Cache Katalog Offline (40 menit)

```dart
// 📄 lib/features/products/data/product_repository.dart
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/error/failure.dart';
import '../domain/product.dart';
import 'product_remote_data_source.dart';

part 'product_repository.g.dart';

/// Strategi offline-first: "network first, fallback ke cache".
/// Berhasil dari network -> simpan ke cache. Gagal karena jaringan ->
/// kembalikan data cache (fromCache: true) agar UI tetap berguna.
class ProductRepository {
  ProductRepository(this._remote, this._db);
  final ProductRemoteDataSource _remote;
  final AppDatabase _db;

  Future<ProductPage> getPage({
    required int limit,
    required int skip,
    CancelToken? cancelToken,
  }) async {
    try {
      final page = await _remote.fetchPage(
        limit: limit,
        skip: skip,
        cancelToken: cancelToken,
      );
      await _db.upsertProducts(page.items.map(_toRow).toList());
      return page;
    } catch (e) {
      final failure = mapDioError(e);
      if (failure is! NetworkFailure) throw failure;
      final cached = await _db.productsPage(limit: limit, offset: skip);
      if (cached.isEmpty && skip == 0) throw failure;
      return ProductPage(
        items: cached.map(_fromRow).toList(),
        total: skip + cached.length, // saat offline tidak tahu total sebenarnya
        fromCache: true,
      );
    }
  }

  Future<ProductPage> search(String q, {CancelToken? cancelToken}) async {
    try {
      return await _remote.search(q, cancelToken: cancelToken);
    } catch (e) {
      throw mapDioError(e);
    }
  }

  Future<Product> detail(int id) async {
    try {
      return await _remote.fetchDetail(id);
    } catch (e) {
      throw mapDioError(e);
    }
  }

  static CachedProductsCompanion _toRow(Product p) => CachedProductsCompanion(
    id: Value(p.id),
    title: Value(p.title),
    description: Value(p.description),
    category: Value(p.category),
    price: Value(p.price),
    rating: Value(p.rating),
    stock: Value(p.stock),
    thumbnail: Value(p.thumbnail),
  );

  static Product _fromRow(CachedProduct r) => Product(
    id: r.id,
    title: r.title,
    description: r.description,
    category: r.category,
    price: r.price,
    rating: r.rating,
    stock: r.stock,
    thumbnail: r.thumbnail,
  );
}

@Riverpod(keepAlive: true)
ProductRepository productRepository(Ref ref) => ProductRepository(
  ref.watch(productRemoteDataSourceProvider),
  ref.watch(appDatabaseProvider),
);
```

> **UI & controller tidak berubah sama sekali.** `ProductListState.fromCache` sudah ada sejak Hari 1; banner "Mode offline" muncul otomatis.

✅ **Checklist Lab 3A:**

- [ ] Online: scroll sampai 40 produk → mode pesawat → tarik refresh → produk tetap tampil + banner offline
- [ ] Hapus data aplikasi, tetap offline → error "Tidak ada koneksi internet"
- [ ] `flutter test test/unit/product_repository_test.dart` lulus

---

## 📘 Sesi 3 — Outbox Pattern & Race Condition (40 menit)

```
User tambah ke keranjang ──► simpan lokal (synced=false) ──► UI langsung update
                                          │
         dipicu: item ditambah / kembali online / workmanager (app tertutup)
                                          ▼
                kirim semua synced=false ──► sukses → synced=true (JIKA qty sama)
                                         └─► gagal → biarkan, coba lagi nanti
```

**Race condition yang sering terlewat:** sync membaca `qty=1` → request berjalan 2 detik → user menekan "tambah" lagi (`qty=2`) → response sukses → `markSynced` menandai item **synced** → qty 2 **tidak pernah terkirim**.

Solusi: tandai synced **hanya jika** qty di DB masih sama dengan yang dikirim (lihat `markSynced` di Sesi 2), dan jika sync dipanggil saat sedang berjalan, ulangi satu putaran lagi:

```dart
// 📄 lib/features/cart/data/cart_sync_service.dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/dio_client.dart';

part 'cart_sync_service.g.dart';

/// Status koneksi sebagai stream. connectivity_plus hanya tahu ada
/// interface jaringan, BUKAN pasti ada internet -> tetap tangani error.
@Riverpod(keepAlive: true)
Stream<bool> isOnline(Ref ref) => Connectivity().onConnectivityChanged
    .map((r) => !r.contains(ConnectivityResult.none))
    .distinct();

/// Outbox pattern: kirim item keranjang yang belum tersinkron.
/// Dipicu oleh: (1) item ditambah, (2) kembali online,
/// (3) workmanager di background walau app ditutup (lihat background_sync.dart).
class CartSyncService {
  CartSyncService(this._db, this._dio);
  final AppDatabase _db;
  final Dio _dio;

  bool _running = false;
  bool _runAgain = false;

  /// Mengembalikan jumlah item yang berhasil ditandai tersinkron.
  Future<int> syncNow({int userId = 1}) async {
    if (_running) {
      // Jangan dobel kirim; cukup tandai agar diulang setelah putaran ini.
      _runAgain = true;
      return 0;
    }
    _running = true;
    var synced = 0;
    try {
      do {
        _runAgain = false;
        synced += await _syncOnce(userId);
      } while (_runAgain);
      return synced;
    } finally {
      _running = false;
    }
  }

  Future<int> _syncOnce(int userId) async {
    final pending = await _db.unsyncedCart();
    if (pending.isEmpty) return 0;
    try {
      await _dio.post<Map<String, dynamic>>(
        '/carts/add',
        data: {
          'userId': userId,
          'products': [
            for (final i in pending) {'id': i.productId, 'quantity': i.qty},
          ],
        },
      );
    } on DioException catch (e) {
      debugPrint('Sync gagal, akan dicoba lagi: ${e.message}');
      return 0;
    }
    return _db.markSynced({for (final i in pending) i.productId: i.qty});
  }
}

@Riverpod(keepAlive: true)
CartSyncService cartSyncService(Ref ref) {
  final service = CartSyncService(
    ref.watch(appDatabaseProvider),
    ref.watch(dioProvider),
  );
  // Setiap transisi offline -> online, jalankan sync.
  ref.listen(isOnlineProvider, (prev, next) {
    if (next.value == true && prev?.value != true) unawaited(service.syncNow());
  });
  return service;
}
```

```dart
// 📄 test/unit/cart_database_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokoku_pro/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  CartItemsCompanion item(int id) => CartItemsCompanion.insert(
    productId: Value(id),
    title: 'P$id',
    price: 10,
    thumbnail: '',
  );

  test('menambah produk yang sama menaikkan qty', () async {
    await db.addToCart(item(1));
    await db.addToCart(item(1));
    final cart = await db.watchCart().first;
    expect(cart.single.qty, 2);
  });

  test('markSynced mengubah status item yang dikirim', () async {
    await db.addToCart(item(1));
    await db.addToCart(item(2));
    await db.markSynced({1: 1});
    final pending = await db.unsyncedCart();
    expect(pending.map((e) => e.productId), [2]);
  });

  test(
    'qty berubah SAAT sync berjalan -> item tetap belum tersinkron',
    () async {
      await db.addToCart(item(1));
      final sent = {
        for (final i in await db.unsyncedCart()) i.productId: i.qty,
      };

      await db.addToCart(item(1)); // user menambah lagi sebelum response datang
      final marked = await db.markSynced(sent);

      expect(marked, 0);
      final pending = await db.unsyncedCart();
      expect(pending.single.qty, 2); // akan ikut terkirim di sync berikutnya
    },
  );
}
```

**Konflik antar-perangkat:** tentukan aturannya — *last-write-wins* (capstone), *server wins*, atau *merge* (mis. jumlahkan qty). Dokumentasikan keputusan ini; jangan biarkan "kebetulan".

---

## 🧪 Lab 3B — Keranjang Offline + Sync (70 menit)

```dart
// 📄 lib/features/cart/presentation/cart_providers.dart
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tokoku_core/tokoku_core.dart';

import '../../../core/database/app_database.dart';
import '../../products/domain/product.dart';
import '../data/cart_sync_service.dart';
import '../domain/cart_line.dart';

part 'cart_providers.g.dart';

/// Stream reaktif dari drift: UI otomatis update saat tabel berubah.
@riverpod
Stream<List<CartLine>> cartItems(Ref ref) =>
    ref.watch(appDatabaseProvider).watchCart();

/// Derived state: jumlah item & total (pakai `Money`, bukan double).
@riverpod
({int count, Money total}) cartSummary(Ref ref) {
  final items = ref.watch(cartItemsProvider).value ?? const [];
  return (
    count: items.fold(0, (sum, i) => sum + i.qty),
    total: items.fold(
      Money.zero(.usd),
      (sum, i) => sum + Money.fromDecimal(i.price, .usd) * i.qty,
    ),
  );
}

class CartActions {
  CartActions(this._db, this._sync);
  final AppDatabase _db;
  final CartSyncService _sync;

  /// Simpan lokal dulu (UI langsung update), lalu coba sync di belakang.
  Future<void> add(Product p) async {
    await _db.addToCart(
      CartItemsCompanion.insert(
        productId: Value(p.id),
        title: p.title,
        price: p.price,
        thumbnail: p.thumbnail,
      ),
    );
    unawaited(_sync.syncNow());
  }

  Future<void> remove(int productId) => _db.removeFromCart(productId);

  Future<void> clear() => _db.clearCart();
}

@riverpod
CartActions cartActions(Ref ref) => CartActions(
  ref.watch(appDatabaseProvider),
  ref.watch(cartSyncServiceProvider),
);
```

* `cartItems` = **stream** drift → halaman keranjang & badge nav update otomatis.
* `cartSummary` = **derived state** berisi record `(count, total)` — total memakai `Money` (bukan `double`).
* `CartActions.add` menyimpan lokal **lalu** memicu sync — memperbaiki celah "item yang ditambah saat online tidak pernah tersinkron".

```dart
// 📄 lib/features/cart/presentation/cart_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tokoku_core/tokoku_core.dart';

import '../../../router/app_router.dart';
import 'cart_providers.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartItemsProvider);
    final summary = ref.watch(cartSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Keranjang (${summary.count})')),
      body: switch (items) {
        AsyncData(:final value) when value.isEmpty => const Center(
          child: Text('Keranjang masih kosong'),
        ),
        AsyncData(:final value) => ListView.separated(
          itemCount: value.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final item = value[i];
            return Dismissible(
              key: ValueKey(item.productId),
              direction: .endToStart,
              onDismissed: (_) =>
                  ref.read(cartActionsProvider).remove(item.productId),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: ListTile(
                title: Text(item.title),
                subtitle: Text(
                  '${item.qty} × ${Money.fromDecimal(item.price, .usd)}',
                ),
                trailing: Icon(
                  item.synced ? Icons.cloud_done : Icons.cloud_upload_outlined,
                  semanticLabel: item.synced ? 'Tersinkron' : 'Menunggu sync',
                ),
              ),
            );
          },
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total: ${summary.total.format()}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                key: const Key('checkout-button'),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Checkout'),
                onPressed: summary.count == 0
                    ? null
                    : () async {
                        // Demo: ID pesanan dibuat lokal. Di app nyata ID ini
                        // berasal dari response API pembuatan pesanan.
                        final id =
                            'ORD-${DateTime.now().millisecondsSinceEpoch}';
                        await ref.read(cartActionsProvider).clear();
                        if (!context.mounted) return;
                        unawaited(context.push(Routes.order(id)));
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

✅ **Checklist Lab 3B:**

- [ ] Tambah produk **offline** → muncul dengan ikon ☁️⬆; badge nav bertambah
- [ ] Online kembali → ikon ☁️✔ + log `POST /carts/add`
- [ ] Tambah produk saat **online** → langsung tersinkron (tanpa harus offline dulu)
- [ ] Swipe kiri menghapus item; total memakai format `Money`
- [ ] Test race condition di `cart_database_test.dart` lulus

---

## 📘 Sesi 4 — Background Work (40 menit)

| Mekanisme | Kapan jalan | Contoh |
|---|---|---|
| `Isolate.run` / `compute` | Saat app terbuka, di thread lain | Parsing JSON besar (Hari 4) |
| **workmanager** (Android WorkManager / iOS BGTaskScheduler) | **Walau app ditutup**, saat sistem mengizinkan | Sync keranjang periodik |
| FCM data message | Dipicu server | "Ada update, silakan sync" (Hari 5) |

Batasan yang harus dijelaskan ke stakeholder:

* Periodik minimal **15 menit**, waktunya **tidak presisi** (Doze, App Standby, hemat baterai vendor).
* Isolate background **tidak berbagi memori** dengan UI: tidak ada `ProviderScope`, tidak ada state app. Semua dependensi dibuat ulang.

```dart
// 📄 lib/features/cart/data/background_sync.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'cart_sync_service.dart';

const cartSyncTask = 'tokoku.cartSync';

/// Titik masuk isolate background. WAJIB top-level + `vm:entry-point`
/// (kalau tidak, tree-shaking release build membuangnya).
///
/// Isolate ini TIDAK berbagi memori dengan UI: tidak ada ProviderScope,
/// tidak ada state Riverpod dari app. Kita buat ProviderContainer sendiri ->
/// provider yang sama (DB, Dio, CartSyncService) dipakai ulang tanpa duplikasi.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != cartSyncTask) return true;
    final container = ProviderContainer();
    try {
      final synced = await container.read(cartSyncServiceProvider).syncNow();
      debugPrint('[bg] $synced item keranjang tersinkron');
      return true;
    } catch (e) {
      debugPrint('[bg] sync gagal: $e');
      return false; // WorkManager akan menjadwalkan ulang (backoff)
    } finally {
      container.dispose();
    }
  });
}

/// Android membatasi tugas periodik minimal 15 menit & menjalankannya saat
/// sistem mengizinkan (Doze, hemat baterai) -> "kurang lebih tiap 15 menit".
Future<void> registerBackgroundSync() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    cartSyncTask,
    cartSyncTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
```

Didaftarkan di `main.dart` (lihat Hari 5 untuk versi lengkap):

```dart
if (defaultTargetPlatform == TargetPlatform.android) {
  await registerBackgroundSync();
}
```

### Riverpod offline persistence (eksperimental)

Riverpod 3 bisa **menyimpan state Notifier ke disk** otomatis (mis. dengan `riverpod_sqflite`):

```dart
// Ilustrasi — API eksperimental, bisa berubah tanpa major version
import 'package:flutter_riverpod/experimental/persist.dart';

@riverpod
@JsonPersist()
class Wishlist extends _$Wishlist {
  @override
  List<int> build() {
    persist(ref.watch(storageProvider.future)); // jangan di-await
    return const [];
  }
}
```

| Pakai persistence Riverpod | Pakai drift (capstone) |
|---|---|
| State kecil per-provider (wishlist, draft form) | Data relasional, query, paging, stream lintas layar |
| Tidak butuh query | Butuh migrasi skema terkontrol & test in-memory |

---

## 📘 Sesi 5 — Real-time: Polling vs SSE vs WebSocket (20 menit)

| Teknik | Arah | Kelebihan | Kekurangan |
|---|---|---|---|
| Polling | klien → server | Sederhana | Boros baterai & kuota, lambat |
| SSE | server → klien | HTTP biasa, auto-reconnect di browser | Satu arah |
| **WebSocket** | dua arah | Latensi rendah | Wajib menangani putus-sambung sendiri |
| FCM | server → device | Jalan walau app tertutup | Bukan untuk aliran data cepat |

Di jaringan seluler, koneksi **pasti** putus (pindah BTS, masuk lift, app ke background). Kode real-time tanpa reconnect = UI yang diam selamanya.

---

## 🧪 Lab 3C — Background Sync + Status Pesanan Live (90 menit)

### Langkah 1 — Jalankan server WebSocket lokal

```dart
// 📄 tool/order_status_server.dart
// Server WebSocket mini untuk Lab Hari 3 (murni dart:io, tanpa paket).
//
//   dart run tool/order_status_server.dart          # port 8080
//
// Emulator Android mengakses komputer Anda lewat ws://10.0.2.2:8080.
// Setiap koneksi ke /orders/<id> menerima status bertahap tiap 3 detik.
// Kirim teks "drop" dari klien untuk mensimulasikan koneksi putus.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _steps = ['created', 'processing', 'shipped', 'delivered'];

/// Progres per pesanan disimpan agar reconnect melanjutkan status terakhir.
final _progress = <String, int>{};

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 8080;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Order status server: ws://localhost:$port/orders/<id>');

  await for (final request in server) {
    final segments = request.uri.pathSegments;
    if (segments.length != 2 || segments.first != 'orders') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }
    final orderId = segments[1];
    final socket = await WebSocketTransformer.upgrade(request);
    stdout.writeln('+ $orderId terhubung');

    void send() {
      final i = _progress[orderId] ?? 0;
      socket.add(jsonEncode({'orderId': orderId, 'status': _steps[i]}));
    }

    send();
    final timer = Timer.periodic(const Duration(seconds: 3), (t) {
      final next = (_progress[orderId] ?? 0) + 1;
      if (next >= _steps.length) {
        t.cancel();
        unawaited(socket.close());
        return;
      }
      _progress[orderId] = next;
      send();
    });

    socket.listen(
      (msg) {
        if (msg == 'drop') socket.close(WebSocketStatus.goingAway);
      },
      onDone: () {
        timer.cancel();
        stdout.writeln('- $orderId terputus');
      },
    );
  }
}
```

```bash
dart run tool/order_status_server.dart     # ws://localhost:8080/orders/<id>
```

> `android/app/src/debug/AndroidManifest.xml` mengizinkan `ws://` (cleartext) **hanya** di debug. Produksi wajib `wss://`.

### Langkah 2 — Domain & socket dengan reconnect

```dart
// 📄 lib/features/orders/domain/order_status.dart
import 'dart:convert';

/// Status pesanan. Enum + primary constructor (Dart 3.13).
enum OrderStatus(final String label, final bool isFinal) {
  created('Pesanan dibuat', false),
  processing('Sedang diproses', false),
  shipped('Dalam pengiriman', false),
  delivered('Pesanan sampai', true);

  /// Pesan dari server: `{"orderId":"ORD-1","status":"shipped"}`.
  /// Pattern matching pada Map (Dart 3) = parsing JSON yang aman tanpa cast.
  static OrderStatus? tryParse(String message) {
    final Object? json;
    try {
      json = jsonDecode(message);
    } on FormatException {
      return null;
    }
    if (json case {'status': final String name}) {
      return values.asNameMap()[name];
    }
    return null;
  }
}
```

```dart
// 📄 lib/features/orders/data/order_status_socket.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/env.dart';
import '../domain/order_status.dart';

part 'order_status_socket.g.dart';

/// Membuka koneksi dan mengalirkan pesan teks. Dibuat sebagai fungsi agar
/// bisa diganti di test (tanpa server sungguhan).
typedef MessageConnector = Stream<String> Function(Uri uri);

/// Implementasi nyata: WebSocket. `finally` di generator `async*` dijalankan
/// saat subscriber berhenti mendengarkan -> socket selalu ditutup.
Stream<String> webSocketConnector(Uri uri) async* {
  final channel = WebSocketChannel.connect(uri);
  try {
    await channel.ready;
    yield* channel.stream.map((m) => m.toString());
  } finally {
    await channel.sink.close();
  }
}

/// Real-time status pesanan dengan reconnect otomatis (exponential backoff).
///
/// Pola penting koneksi real-time di mobile: jaringan seluler SERING putus
/// (pindah BTS, masuk lift). Tanpa reconnect, UI diam selamanya.
class OrderStatusSocket {
  OrderStatusSocket({
    required this.baseUri,
    MessageConnector connector = webSocketConnector,
    Duration Function(int attempt)? backoff,
  }) : _connect = connector,
       _backoff = backoff ?? _defaultBackoff;

  final Uri baseUri;
  final MessageConnector _connect;
  final Duration Function(int attempt) _backoff;

  /// 1s, 2s, 4s, 8s ... maks 30s.
  static Duration _defaultBackoff(int attempt) =>
      Duration(seconds: min(30, pow(2, attempt - 1).toInt()));

  Stream<OrderStatus> watch(String orderId) async* {
    final uri = baseUri.replace(path: '/orders/$orderId');
    var attempt = 0;
    while (true) {
      try {
        await for (final message in _connect(uri)) {
          attempt = 0; // koneksi sehat -> reset backoff
          final status = OrderStatus.tryParse(message);
          if (status == null) continue; // abaikan pesan tak dikenal
          yield status;
          if (status.isFinal) return; // selesai, tidak perlu reconnect
        }
      } catch (e) {
        debugPrint('WebSocket putus: $e');
      }
      attempt++;
      await Future<void>.delayed(_backoff(attempt));
    }
  }
}

@Riverpod(keepAlive: true)
OrderStatusSocket orderStatusSocket(Ref ref) =>
    OrderStatusSocket(baseUri: Uri.parse(Env.wsBaseUrl));

/// autoDispose: keluar dari halaman -> subscription dibatalkan -> socket ditutup.
@riverpod
Stream<OrderStatus> orderStatus(Ref ref, String orderId) =>
    ref.watch(orderStatusSocketProvider).watch(orderId);
```

Poin desain:

* `MessageConnector` bisa diganti → test tanpa server (Hari 4).
* Generator `async*` + `finally` → socket **selalu** ditutup ketika provider autoDispose berhenti didengarkan.
* Backoff di-reset setelah pesan pertama diterima (koneksi sehat).

### Langkah 3 — Halaman status

```dart
// 📄 lib/features/orders/presentation/order_status_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/order_status_socket.dart';
import '../domain/order_status.dart';

class OrderStatusPage extends ConsumerWidget {
  const OrderStatusPage({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(orderStatusProvider(orderId));
    // Selama reconnect, stream tidak memancarkan apa pun -> AsyncData terakhir
    // tetap tampil (UI tidak "berkedip" kembali ke loading).
    final current = status.value;

    return Scaffold(
      appBar: AppBar(title: Text('Pesanan $orderId')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final step in OrderStatus.values)
            ListTile(
              leading: Icon(
                current != null && step.index <= current.index
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: current == step
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(step.label),
            ),
          const SizedBox(height: 16),
          switch (status) {
            AsyncError(:final error) => Text('Koneksi bermasalah: $error'),
            AsyncData(value: OrderStatus(isFinal: true)) => const Text(
              'Terima kasih sudah berbelanja 🎉',
            ),
            _ => const LinearProgressIndicator(),
          },
        ],
      ),
    );
  }
}
```

Tombol **Checkout** di halaman keranjang membuka `/orders/<id>`.

### Langkah 4 — Uji

1. Checkout → status bergerak *dibuat → diproses → dikirim → sampai* tiap 3 detik.
2. Matikan server di tengah jalan (Ctrl+C), nyalakan lagi → app **tersambung ulang** dan melanjutkan status (log `WebSocket putus` lalu tersambung).
3. Keluar dari halaman → log server `- ORD-... terputus` (socket ditutup oleh autoDispose).
4. Background sync: tambah item offline → tutup app → nyalakan internet → tunggu ±15 menit (atau paksa via `adb shell cmd jobscheduler run -f id.pelatihan.tokoku_pro.dev <job-id>` / App Inspection → Background Task Inspector) → item menjadi ☁️✔ saat app dibuka.

✅ **Checklist Lab 3C:**

- [ ] Status pesanan live + reconnect setelah server dimatikan/dinyalakan
- [ ] Socket tertutup saat keluar halaman
- [ ] Background Task Inspector menampilkan pekerjaan `tokoku.cartSync`

---

## 🧠 Kuis Harian

1. Jelaskan race condition pada outbox sync dan bagaimana `markSynced` mencegahnya.
2. Mengapa isolate workmanager harus membuat `ProviderContainer` sendiri?
3. Kenapa `shareAcrossIsolates: true` diperlukan di `driftDatabase`?
4. Apa yang terjadi pada socket jika `orderStatusProvider` dibuat `keepAlive`?
5. Kapan memilih offline persistence Riverpod dibanding drift?

## 🏠 Tugas Rumah (PR)

1. Ubah katalog menjadi **stale-while-revalidate** (cache dulu, lalu perbarui dari API).
2. Tambahkan kolom `note` ke `CartItems` dengan **migrasi v2** + test migrasi dari `make-migrations`.
3. Tambahkan **heartbeat**: jika 30 detik tidak ada pesan, anggap koneksi mati dan reconnect. Uji dengan connector palsu yang diam.
