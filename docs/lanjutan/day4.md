# Hari 4 — Kualitas, Performa & Kode Native

## 🎯 Tujuan Pembelajaran

* Menguji **logika async yang sulit**: interceptor refresh token (request bersamaan), stream WebSocket dengan reconnect, provider Riverpod dengan `ProviderContainer.test`.
* Menulis widget test dengan **override provider** dan mematikan auto-retry.
* Menulis **golden test modern dengan alchemist** (pengganti `golden_toolkit` yang sudah *discontinued*).
* Menulis **test E2E dengan Patrol** yang bisa berinteraksi dengan **dialog native** (izin notifikasi).
* Mendeteksi **memory leak** di test (leak tracking).
* Mem-profiling dengan DevTools, memindahkan kerja berat ke **isolate**, dan menjadikan coverage *quality gate*.
* Memanggil **kode Kotlin secara type-safe dengan Pigeon**.

> Dasar `test()`/`testWidgets()`, mockito, integration_test, golden_toolkit, dan coverage sudah dipelajari di `flutter_test` dan `day9`. Hari ini fokus pada teknik yang belum disentuh.

## ⏰ Jadwal

| Waktu | Durasi | Sesi |
|---|---|---|
| 08:00 – 08:15 | 15' | Review PR Hari 3 |
| 08:15 – 08:35 | 20' | mockito → mocktail, apa yang layak diuji di app Riverpod |
| 08:35 – 10:00 | 85' | 🧪 **Lab 4A**: test interceptor, stream, controller, redirect |
| 10:00 – 10:10 | 10' | Coffee break |
| 10:10 – 11:00 | 50' | 🧪 **Lab 4B**: widget test + override, alchemist, leak tracking |
| 11:00 – 12:00 | 60' | 🧪 **Lab 4C**: Patrol E2E (dialog izin native) |
| 12:00 – 13:00 | 60' | ISHOMA |
| 13:00 – 13:15 | 15' | Coverage & quality gate |
| 13:15 – 14:00 | 45' | DevTools: rebuild, jank, memory, app size + isolate |
| 14:00 – 14:30 | 30' | Platform channel: `MethodChannel` vs **Pigeon** vs FFI |
| 14:30 – 15:30 | 60' | 🧪 **Lab 4D**: Pigeon (info perangkat dari Kotlin) + profiling |
| 15:30 – 15:45 | 15' | Kuis harian |
| 15:45 – 16:00 | 15' | Rangkuman & PR |

---

## 📘 Sesi 1 — Dari mockito ke mocktail (20 menit)

| | mockito (`day9`, `flutter_test`) | mocktail (capstone) |
|---|---|---|
| Codegen | `@GenerateMocks` + `build_runner` → `*.mocks.dart` | Tidak perlu |
| Stub | `when(mock.f(any))` | `when(() => mock.f(any()))` |
| Argumen named | `anyNamed('x')` | `any(named: 'x')` |
| Tipe kustom di `any()` | otomatis | `registerFallbackValue(...)` di `setUpAll` |

Prioritas test di app Riverpod (piramida):

| Lapisan | Jenis | Alat |
|---|---|---|
| Value object, parser, redirect, prompt AI | Unit murni | `test()`, `expect()` |
| Repository, interceptor, socket | Unit + fake | mocktail, fake `HttpClientAdapter`, fake connector, drift in-memory |
| Notifier/AsyncNotifier | Unit | `ProviderContainer.test(overrides: ...)` |
| Halaman | Widget | `ProviderScope(overrides, retry: ...)` |
| Tampilan piksel | Golden | **alchemist** |
| Alur di device + dialog native | E2E | **Patrol** |

---

## 🧪 Lab 4A — Test Logika Async yang Sulit (85 menit)

### Helper bersama

```dart
// 📄 test/helpers/fakes.dart
import 'package:mocktail/mocktail.dart';
import 'package:tokoku_pro/features/products/data/product_remote_data_source.dart';
import 'package:tokoku_pro/features/products/data/product_repository.dart';
import 'package:tokoku_pro/features/products/domain/product.dart';

class MockRemote extends Mock implements ProductRemoteDataSource {}

class MockProductRepository extends Mock implements ProductRepository {}

List<Product> fakeProducts(int n, {int start = 1}) => [
  for (var i = start; i < start + n; i++)
    Product(id: i, title: 'Produk $i', price: i * 1.5, thumbnail: ''),
];
```

### Interceptor: request bersamaan, logout palsu, hang

Ini test **paling bernilai** di capstone: bug-nya (deadlock, refresh berganda, logout palsu) hampir mustahil ditemukan dengan uji manual.

```dart
// 📄 test/unit/auth_interceptor_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokoku_pro/core/network/auth_interceptor.dart';
import 'package:tokoku_pro/core/storage/token_storage.dart';

/// Penyimpanan token in-memory: berbagi state antar-request seperti aslinya,
/// sehingga skenario "request lain sudah me-refresh" bisa diuji.
class InMemoryTokenStorage extends TokenStorage {
  InMemoryTokenStorage({this.access, this.refresh})
    : super(const FlutterSecureStorage());
  String? access;
  String? refresh;
  int clears = 0;

  @override
  Future<String?> get accessToken async => access;
  @override
  Future<String?> get refreshToken async => refresh;
  @override
  Future<void> save({required String access, required String refresh}) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> clear() async {
    clears++;
    access = refresh = null;
  }
}

/// Adapter palsu: menggantikan HTTP sungguhan dengan respons terprogram.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions o) handler;
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? _,
    Future<void>? _,
  ) {
    calls.add('${o.method} ${o.path} ${o.headers['Authorization'] ?? '-'}');
    return handler(o);
  }

  @override
  void close({bool force = false}) {}
}

Future<ResponseBody> json(int status, Object body) async =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  late InMemoryTokenStorage storage;
  late Dio api;
  late Dio plain;
  late FakeAdapter apiAdapter;
  var expired = 0;

  void setUpDio({
    required Future<ResponseBody> Function(RequestOptions) apiHandler,
    required Future<ResponseBody> Function(RequestOptions) plainHandler,
  }) {
    apiAdapter = FakeAdapter(apiHandler);
    api = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = apiAdapter;
    plain = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = FakeAdapter(plainHandler);
    api.interceptors.add(
      AuthInterceptor(
        storage: storage,
        plainDio: plain,
        onSessionExpired: () => expired++,
      ),
    );
  }

  List<String> plainCalls() => (plain.httpClientAdapter as FakeAdapter).calls;

  setUp(() {
    storage = InMemoryTokenStorage(access: 'old', refresh: 'r1');
    expired = 0;
  });

  test('401 -> refresh -> request asli diulang dengan token baru', () async {
    setUpDio(
      apiHandler: (_) => json(401, {'message': 'expired'}),
      // plainDio melayani refresh DAN retry -> bedakan berdasarkan path
      plainHandler: (o) => o.path == '/auth/refresh'
          ? json(200, {'accessToken': 'new', 'refreshToken': 'r2'})
          : json(200, {'ok': true}),
    );

    final res = await api.get<Map<String, dynamic>>('/auth/me');

    expect(res.data, {'ok': true});
    expect(apiAdapter.calls, ['GET /auth/me Bearer old']);
    expect(plainCalls(), [
      startsWith('POST /auth/refresh'),
      'GET /auth/me Bearer new',
    ]);
    expect((storage.access, storage.refresh), ('new', 'r2'));
  });

  test('3 request gagal 401 bersamaan -> refresh HANYA sekali', () async {
    setUpDio(
      apiHandler: (_) => json(401, {}),
      plainHandler: (o) => o.path == '/auth/refresh'
          ? json(200, {'accessToken': 'new', 'refreshToken': 'r2'})
          : json(200, {'path': o.path}),
    );

    final results = await Future.wait([
      api.get<Map<String, dynamic>>('/a'),
      api.get<Map<String, dynamic>>('/b'),
      api.get<Map<String, dynamic>>('/c'),
    ]);

    expect(results.map((r) => r.data!['path']), ['/a', '/b', '/c']);
    expect(
      plainCalls().where((c) => c.contains('/auth/refresh')),
      hasLength(1),
    );
  });

  test('refresh DITOLAK (403) -> token dihapus & sesi berakhir', () async {
    setUpDio(
      apiHandler: (_) => json(401, {}),
      plainHandler: (_) => json(403, {}),
    );

    await expectLater(
      api.get<dynamic>('/products'),
      throwsA(isA<DioException>()),
    );
    expect(storage.clears, 1);
    expect(expired, 1);
  });

  test('jaringan putus saat refresh -> user TIDAK di-logout', () async {
    setUpDio(
      apiHandler: (_) => json(401, {}),
      plainHandler: (o) => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      ),
    );

    await expectLater(
      api.get<dynamic>('/products'),
      throwsA(isA<DioException>()),
    );
    expect(storage.clears, 0);
    expect(storage.access, 'old');
    expect(expired, 0);
  });

  test('respons refresh rusak -> error, BUKAN hang', () async {
    setUpDio(
      apiHandler: (_) => json(401, {}),
      plainHandler: (_) => json(200, {'unexpected': true}), // tanpa token
    );

    await expectLater(
      api.get<dynamic>('/products').timeout(const Duration(seconds: 2)),
      throwsA(isA<DioException>()),
    );
  });
}
```

> 🐞 **Cerita nyata:** versi awal interceptor capstone (1) mengulang request dengan Dio yang sama → test timeout 30 detik (deadlock), dan (2) me-refresh 3× untuk 3 request bersamaan. Kedua bug tertangkap oleh test di atas sebelum sampai ke peserta.

### Stream WebSocket dengan reconnect — tanpa server

```dart
// 📄 test/unit/order_status_socket_test.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tokoku_pro/features/orders/data/order_status_socket.dart';
import 'package:tokoku_pro/features/orders/domain/order_status.dart';

String msg(String status) => jsonEncode({'orderId': 'A1', 'status': status});

void main() {
  test(
    'reconnect otomatis setelah koneksi putus, lalu berhenti di status final',
    () async {
      var connections = 0;
      final socket = OrderStatusSocket(
        baseUri: Uri.parse('ws://test'),
        backoff: (_) => Duration.zero, // test cepat
        connector: (uri) {
          connections++;
          expect(uri.path, '/orders/A1');
          return switch (connections) {
            // Koneksi 1: dapat 2 status lalu PUTUS (error jaringan).
            1 => Stream.fromIterable([
              msg('created'),
              msg('processing'),
            ]).followedBy(Stream.error(Exception('socket closed'))),
            // Koneksi 2: pesan sampah diabaikan, lanjut sampai selesai.
            _ => Stream.fromIterable([
              'bukan json',
              msg('shipped'),
              msg('delivered'),
            ]),
          };
        },
      );

      final statuses = await socket.watch('A1').toList();

      expect(statuses, [
        OrderStatus.created,
        OrderStatus.processing,
        OrderStatus.shipped,
        OrderStatus.delivered,
      ]);
      expect(connections, 2);
    },
  );

  test('tryParse memakai pattern matching Map', () {
    expect(OrderStatus.tryParse(msg('shipped')), OrderStatus.shipped);
    expect(OrderStatus.tryParse('{"status": 42}'), isNull);
    expect(OrderStatus.tryParse('{}'), isNull);
  });
}

extension<T> on Stream<T> {
  Stream<T> followedBy(Stream<T> next) async* {
    yield* this;
    yield* next;
  }
}
```

### Repository offline-first (mocktail + drift in-memory)

```dart
// 📄 test/unit/product_repository_test.dart
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tokoku_pro/core/database/app_database.dart';
import 'package:tokoku_pro/core/error/failure.dart';
import 'package:tokoku_pro/features/products/data/product_repository.dart';
import 'package:tokoku_pro/features/products/domain/product.dart';

import '../helpers/fakes.dart';

void main() {
  late MockRemote remote;
  late AppDatabase db;
  late ProductRepository repo;

  setUp(() {
    remote = MockRemote();
    db = AppDatabase(
      NativeDatabase.memory(),
    ); // DB in-memory: cepat & terisolasi
    repo = ProductRepository(remote, db);
  });

  tearDown(() => db.close());

  DioException offline() => DioException(
    requestOptions: RequestOptions(path: '/products'),
    type: DioExceptionType.connectionError,
  );

  test('online: mengembalikan data API dan menyimpannya ke cache', () async {
    when(
      () => remote.fetchPage(
        limit: 20,
        skip: 0,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => ProductPage(items: fakeProducts(3), total: 3));

    final page = await repo.getPage(limit: 20, skip: 0);

    expect(page.items, hasLength(3));
    expect(page.fromCache, isFalse);
    expect(await db.productsPage(limit: 20, offset: 0), hasLength(3));
  });

  test('offline: fallback ke cache dengan flag fromCache', () async {
    when(
      () => remote.fetchPage(
        limit: 20,
        skip: 0,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => ProductPage(items: fakeProducts(2), total: 2));
    await repo.getPage(limit: 20, skip: 0); // isi cache

    when(
      () => remote.fetchPage(
        limit: 20,
        skip: 0,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenThrow(offline());
    final page = await repo.getPage(limit: 20, skip: 0);

    expect(page.fromCache, isTrue);
    expect(page.items.map((p) => p.title), ['Produk 1', 'Produk 2']);
  });

  test('offline & cache kosong: melempar NetworkFailure', () async {
    when(
      () => remote.fetchPage(
        limit: 20,
        skip: 0,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenThrow(offline());

    expect(
      () => repo.getPage(limit: 20, skip: 0),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
```

### Controller dengan `ProviderContainer.test`

```dart
// 📄 test/unit/product_list_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tokoku_pro/features/products/data/product_repository.dart';
import 'package:tokoku_pro/features/products/domain/product.dart';
import 'package:tokoku_pro/features/products/presentation/product_list_controller.dart';

import '../helpers/fakes.dart';

void main() {
  late MockProductRepository repo;

  setUp(() {
    repo = MockProductRepository();
    when(
      () => repo.getPage(
        limit: 20,
        skip: 0,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => ProductPage(items: fakeProducts(20), total: 25));
    when(() => repo.getPage(limit: 20, skip: 20)).thenAnswer(
      (_) async => ProductPage(items: fakeProducts(5, start: 21), total: 25),
    );
  });

  ProviderContainer makeContainer() => ProviderContainer.test(
    overrides: [productRepositoryProvider.overrideWithValue(repo)],
  );

  test('build() memuat halaman pertama', () async {
    final container = makeContainer();
    final sub = container.listen(productListControllerProvider, (_, _) {});

    final state = await container.read(productListControllerProvider.future);

    expect(state.items, hasLength(20));
    expect(state.hasMore, isTrue);
    sub.close();
  });

  test('loadMore() menambahkan halaman berikutnya', () async {
    final container = makeContainer();
    final sub = container.listen(productListControllerProvider, (_, _) {});
    await container.read(productListControllerProvider.future);

    await container.read(productListControllerProvider.notifier).loadMore();

    final state = container.read(productListControllerProvider).requireValue;
    expect(state.items, hasLength(25));
    expect(state.hasMore, isFalse);
    sub.close();
  });
}
```

> 💡 `container.listen(...)` menjaga provider *autoDispose* tetap hidup selama test.

```bash
flutter test test/unit
```

---

## 🧪 Lab 4B — Widget Test, Golden (alchemist) & Leak Tracking (50 menit)

### Widget test dengan override + tanpa auto-retry

```dart
// 📄 test/widget/product_list_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tokoku_pro/core/error/failure.dart';
import 'package:tokoku_pro/features/products/data/product_repository.dart';
import 'package:tokoku_pro/features/products/domain/product.dart';
import 'package:tokoku_pro/features/products/presentation/product_list_page.dart';

import '../helpers/fakes.dart';

void main() {
  late MockProductRepository repo;
  setUp(() => repo = MockProductRepository());

  Widget harness() => ProviderScope(
    overrides: [productRepositoryProvider.overrideWithValue(repo)],
    // Matikan auto-retry Riverpod 3 agar error langsung tampil di test
    retry: (_, _) => null,
    child: const MaterialApp(home: ProductListPage()),
  );

  testWidgets('menampilkan grid produk', (tester) async {
    when(
      () => repo.getPage(
        limit: any(named: 'limit'),
        skip: any(named: 'skip'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => ProductPage(items: fakeProducts(4), total: 4));

    await tester.pumpWidget(harness());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(ProductCard), findsNWidgets(4));
    expect(find.text('Produk 1'), findsOneWidget);
  });

  testWidgets('menampilkan pesan error + tombol coba lagi', (tester) async {
    when(
      () => repo.getPage(
        limit: any(named: 'limit'),
        skip: any(named: 'skip'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenThrow(const NetworkFailure());

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada koneksi internet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Coba lagi'), findsOneWidget);
  });
}
```

> Riverpod 3 **auto-retry** provider yang error. Di test, `retry: (_, _) => null` membuat error langsung tampil dan tidak meninggalkan *timer*.

### Alur router lengkap (redirect auth)

```dart
// 📄 test/widget/router_redirect_test.dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokoku_pro/app.dart';
import 'package:tokoku_pro/core/database/app_database.dart';
import 'package:tokoku_pro/core/settings/theme_mode_controller.dart';
import 'package:tokoku_pro/features/auth/domain/app_user.dart';
import 'package:tokoku_pro/features/auth/presentation/auth_controller.dart';
import 'package:tokoku_pro/features/auth/presentation/login_page.dart';
import 'package:tokoku_pro/features/cart/data/cart_sync_service.dart';
import 'package:tokoku_pro/router/app_router.dart';

/// Fake controller: kita kendalikan status login secara manual.
class FakeAuthController extends AuthController {
  @override
  Future<AppUser?> build() async => null;

  @override
  Future<void> login(String username, String password) async {
    state = const AsyncData(
      AppUser(
        id: 1,
        username: 'emilys',
        email: 'e@x.com',
        firstName: 'Emily',
        lastName: 'J',
      ),
    );
  }
}

class FakeThemeMode extends ThemeModeController {
  @override
  Future<ThemeMode> build() async => ThemeMode.light;
}

void main() {
  testWidgets(
    'deep link /cart saat belum login -> login -> mendarat di /cart',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final container = ProviderContainer.test(
        overrides: [
          authControllerProvider.overrideWith(FakeAuthController.new),
          themeModeControllerProvider.overrideWith(FakeThemeMode.new),
          appDatabaseProvider.overrideWithValue(db),
          isOnlineProvider.overrideWith((ref) => Stream.value(false)),
        ],
        retry: (_, _) => null,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TokoKuApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      // Seperti deep link tokoku://app/cart saat user belum login.
      container.read(appRouterProvider).go('/cart');
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsNothing);
      expect(find.text('Keranjang masih kosong'), findsOneWidget);

      // Bersihkan stream drift sebelum test selesai
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    },
  );
}
```

### Golden test dengan alchemist

`golden_toolkit` (dipakai di `day9`/`flutter_test`) sudah **discontinued**. alchemist memisahkan dua jenis golden:

| Jenis | Teks | Dipakai untuk |
|---|---|---|
| **CI golden** | Kotak (font Ahem) → identik di semua OS | Dibandingkan di CI (Linux) |
| **Platform golden** | Font asli | Dilihat manusia saat review, hanya lokal |

```dart
// 📄 test/flutter_test_config.dart
import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// Dijalankan otomatis oleh `flutter test` sebelum SETIAP file test di folder
/// ini (nama file wajib `flutter_test_config.dart`).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // 1) Leak tracking global: widget test gagal jika ada objek Disposable
  //    (TextEditingController, AnimationController, ...) yang tidak di-dispose.
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withIgnored(
    // Objek internal paket pihak ketiga di luar kendali kita.
    createdByTestHelpers: true,
  );

  // 2) alchemist: CI golden (teks berupa kotak, identik di semua OS) selalu
  //    dibuat; platform golden (font asli) hanya di mesin developer.
  final isCi = Platform.environment.containsKey('CI');
  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(enabled: !isCi),
    ),
    run: testMain,
  );
}
```

```dart
// 📄 test/golden/product_card_golden_test.dart
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:tokoku_pro/features/products/domain/product.dart';
import 'package:tokoku_pro/features/products/presentation/product_list_page.dart';

void main() {
  Widget card(Product p) =>
      SizedBox(width: 200, height: 280, child: ProductCard(product: p));

  // Satu file golden berisi beberapa skenario -> review visual sekaligus.
  goldenTest(
    'ProductCard dalam berbagai kondisi',
    fileName: 'product_card',
    builder: () => GoldenTestGroup(
      columns: 3,
      children: [
        GoldenTestScenario(
          name: 'normal',
          child: card(
            const Product(id: 1, title: 'Kopi Gayo 250g', price: 7.5),
          ),
        ),
        GoldenTestScenario(
          name: 'judul panjang',
          child: card(
            const Product(
              id: 2,
              title: 'Laptop Gaming Ultra Tipis 16 inci RTX Edisi Terbatas',
              price: 1299.99,
            ),
          ),
        ),
        GoldenTestScenario.withTextScaleFactor(
          name: 'teks 1.5x (aksesibilitas)',
          textScaler: const TextScaler.linear(1.5),
          child: card(const Product(id: 3, title: 'Teh Melati', price: 2)),
        ),
      ],
    ),
  );
}
```

```bash
flutter test --update-goldens test/golden   # buat/perbarui gambar acuan
flutter test test/golden                    # bandingkan
```

### Leak tracking

Flutter melacak objek `Disposable` (controller, `ChangeNotifier`, dll.) yang tidak pernah di-`dispose`. Aktifkan per test atau global:

```dart
testWidgets(
  'halaman login tidak bocor',
  experimentalLeakTesting: LeakTesting.settings.withTrackedAll(),
  (tester) async { ... },
);
```

Lihat `test/flutter_test_config.dart` di atas: leak tracking aktif **global** untuk semua widget test capstone. Coba hapus `_username.dispose()` di `login_page.dart` lalu jalankan `flutter test test/widget` → test gagal dengan laporan `notDisposed`.

---

## 🧪 Lab 4C — E2E dengan Patrol (60 menit)

`integration_test` (yang dipakai di `day9`) **tidak bisa menyentuh UI native**: dialog izin notifikasi, notifikasi sistem, pengaturan Wi-Fi. Patrol memperluas `integration_test` dengan kontrol native.

```bash
dart pub global activate patrol_cli
patrol doctor
```

Konfigurasi ada di `pubspec.yaml` (bagian `patrol:`) dan `android/app/build.gradle.kts` (`testInstrumentationRunner`) — lihat capstone.

```dart
// 📄 patrol_test/app_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patrol/patrol.dart';
import 'package:tokoku_pro/app.dart';

/// Jalankan di emulator/device:
///   patrol test -t patrol_test/app_flow_test.dart --flavor dev \
///     --dart-define-from-file=config/dev.json
void main() {
  patrolTest('login -> detail -> keranjang -> checkout -> status pesanan', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const ProviderScope(child: TokoKuApp()));

    // Dialog izin NATIVE (bukan widget Flutter) -> hanya bisa lewat Patrol.
    if (await $.platform.mobile.isPermissionDialogVisible()) {
      await $.platform.mobile.grantPermissionWhenInUse();
    }

    // clearPackageData=true -> setiap test mulai dari kondisi belum login.
    await $(const Key('login-button')).tap();
    await $('Katalog').waitUntilVisible();

    await $(Card).at(0).tap();
    await $('Tambah ke Keranjang').tap();
    await $('Ditambahkan ke keranjang').waitUntilVisible();

    await $.tester.pageBack();
    await $('Keranjang').tap();
    await $(const Key('checkout-button')).tap();
    await $('Pesanan dibuat').waitUntilVisible();
  });
}
```

```bash
patrol test -t patrol_test/app_flow_test.dart --flavor dev \
  --dart-define-from-file=config/dev.json
```

| `integration_test` | Patrol |
|---|---|
| Hanya widget Flutter | + dialog izin, notifikasi, toggle Wi-Fi/mode pesawat |
| Semua test berbagi satu proses app | Isolasi penuh per test + sharding |
| `find.byKey(...)` | Finder ringkas `$(Key('...'))`, `$('Teks')` |

> Patrol di CI butuh emulator (lebih lambat & kadang *flaky*). Jalankan di workflow terpisah (nightly), bukan di setiap PR.

---

## 📘 Sesi 2 — Coverage & Quality Gate (15 menit)

```bash
flutter test --coverage
lcov --remove coverage/lcov.info '**/*.g.dart' '**/*.freezed.dart' -o coverage/lcov.info
lcov --summary coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html
```

`day9` mengunggah coverage ke Codecov (informasi). Di capstone, coverage menjadi **gerbang**: PR gagal bila < 70% (Hari 5).

---

## 📘 Sesi 3 — Performa dengan DevTools (45 menit)

Selalu ukur di **profile mode** (`flutter run --profile --flavor dev`).

| Tab DevTools | Gunakan untuk |
|---|---|
| **Performance** | Frame > 16 ms (60 Hz) / 8 ms (120 Hz); UI vs Raster thread |
| **Inspector → Track widget rebuilds** | Widget yang rebuild berlebihan |
| **CPU Profiler** | Fungsi Dart berat (parsing, sorting) |
| **Memory** | Kebocoran, ukuran decode gambar |
| **Network** | Request duplikat, payload besar |
| **App Size** | `flutter build apk --analyze-size --target-platform android-arm64 --flavor prod` |

| Masalah | Solusi | Di capstone |
|---|---|---|
| Rebuild seluruh layar | Pecah widget, `const`, `select` | Badge keranjang `select((s) => s.count)` |
| Gambar besar memakan RAM | `memCacheWidth` sesuai ukuran tampil | `CachedNetworkImage(memCacheWidth: 400)` |
| Parsing JSON besar → jank | `compute` / `Isolate.run` | `parseProductsInBackground` |
| Request berlebihan | Debounce, `CancelToken`, cache provider | Pencarian |
| Provider bekerja di tab tak terlihat | Riverpod 3 **pause** otomatis | `StatefulShellRoute` |

```dart
// 📄 lib/core/utils/background_parser.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../features/products/domain/product.dart';

/// Parsing JSON besar di isolate lain agar UI thread tidak "jank".
/// `compute` bekerja di semua platform (di web berjalan di thread yang sama).
/// Untuk mobile/desktop saja, `Isolate.run(() => ...)` juga bisa dipakai.
Future<List<Product>> parseProductsInBackground(String responseBody) =>
    compute(_parseProducts, responseBody);

List<Product> _parseProducts(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  return (json['products'] as List)
      .cast<Map<String, dynamic>>()
      .map(Product.fromJson)
      .toList();
}
```

```dart
// 📄 test/unit/background_parser_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tokoku_pro/core/utils/background_parser.dart';

void main() {
  test('parse 5.000 produk di background', () async {
    final body = jsonEncode({
      'products': [
        for (var i = 0; i < 5000; i++) {'id': i, 'title': 'P$i', 'price': i},
      ],
    });
    final products = await parseProductsInBackground(body);
    expect(products, hasLength(5000));
    expect(products.last.price, 4999.0); // int JSON -> double otomatis
  });
}
```

---

## 📘 Sesi 4 — Platform Channel: MethodChannel vs Pigeon vs FFI (30 menit)

| Pendekatan | Kontrak | Risiko | Cocok untuk |
|---|---|---|---|
| `MethodChannel` manual | String nama method + `Map` dinamis | Salah ketik/tipe = crash runtime | Prototipe |
| **Pigeon** | Kelas Dart → generate Dart + Kotlin/Swift | Salah tipe = **error compile** | API native milik app |
| FFI (`dart:ffi` + `ffigen`/`jnigen`) | Panggil C/Java/ObjC langsung | Manajemen memori | Library C/performa tinggi |

---

## 🧪 Lab 4D — Pigeon: Info Perangkat dari Kotlin (60 menit)

### Langkah 1 — Kontrak

```dart
// 📄 pigeons/device_api.dart
// Definisi kontrak Dart <-> native. Generate kode dengan:
//   dart run pigeon --input pigeons/device_api.dart
// Hasil: lib/core/platform/device_api.g.dart (Dart) + DeviceApi.g.kt (Kotlin).
// Implementasi Kotlin ditulis manual di MainActivity.kt.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/platform/device_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/id/pelatihan/tokoku_pro/DeviceApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'id.pelatihan.tokoku_pro'),
  ),
)
class DeviceInfo {
  DeviceInfo({
    required this.model,
    required this.osVersion,
    required this.batteryLevel,
  });

  String model;
  String osVersion;
  int batteryLevel;
}

/// HostApi = dipanggil dari Dart, diimplementasikan di native.
@HostApi()
abstract class DeviceApi {
  DeviceInfo getDeviceInfo();
}
```

```bash
dart run pigeon --input pigeons/device_api.dart
```

### Langkah 2 — Implementasi Kotlin

```kotlin
// 📄 android/app/src/main/kotlin/id/pelatihan/tokoku_pro/MainActivity.kt
package id.pelatihan.tokoku_pro

import android.content.Context
import android.os.BatteryManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Daftarkan implementasi native untuk API yang di-generate Pigeon.
        DeviceApi.setUp(flutterEngine.dartExecutor.binaryMessenger, DeviceApiImpl(this))
    }
}

/// Implementasi interface `DeviceApi` hasil generate Pigeon (DeviceApi.g.kt).
/// Type-safe: salah tipe/nama method = error compile, bukan crash runtime
/// seperti MethodChannel manual dengan string.
private class DeviceApiImpl(private val context: Context) : DeviceApi {
    override fun getDeviceInfo(): DeviceInfo {
        val battery = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        return DeviceInfo(
            model = "${Build.MANUFACTURER} ${Build.MODEL}",
            osVersion = Build.VERSION.RELEASE,
            batteryLevel = battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY).toLong(),
        )
    }
}
```

### Langkah 3 — Provider & UI

```dart
// 📄 lib/core/platform/device_info_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'device_api.g.dart';

part 'device_info_provider.g.dart';

@Riverpod(keepAlive: true)
DeviceApi deviceApi(Ref ref) => DeviceApi();

/// `null` jika platform belum mengimplementasikan API (mis. iOS di capstone
/// ini, atau widget test) -> UI cukup menyembunyikan info perangkat.
@riverpod
Future<DeviceInfo?> deviceInfo(Ref ref) async {
  try {
    return await ref.watch(deviceApiProvider).getDeviceInfo();
  } on PlatformException catch (e) {
    debugPrint('DeviceApi tidak tersedia: ${e.message}');
    return null;
  } on MissingPluginException {
    return null;
  }
}
```

Halaman Profil menampilkan model, versi Android, dan baterai bila tersedia (`ProfilePage`).

### Langkah 4 — Profiling

1. `flutter run --profile --flavor dev`, buka DevTools → **Performance**; scroll katalog cepat 3×, catat frame > 16 ms.
2. **Track widget rebuilds**; tambah produk ke keranjang → pastikan grid katalog **tidak** ikut rebuild.
3. Hapus `memCacheWidth` → bandingkan grafik **Memory** saat scroll 100 produk.
4. Tulis `docs/performance-report.md` (≤ 1 halaman): temuan, perbaikan, angka sebelum/sesudah.

✅ **Checklist Lab 4D:** info perangkat tampil di Profil (Android); test lain tetap lulus (provider mengembalikan `null` di test); laporan profiling ada.

---

## 🧠 Kuis Harian

1. Mengapa test interceptor memakai penyimpanan token in-memory, bukan mock dengan nilai tetap?
2. Bagaimana menguji reconnect WebSocket tanpa server sungguhan?
3. Apa beda *CI golden* dan *platform golden* di alchemist?
4. Sebutkan 2 hal yang bisa dilakukan Patrol tetapi tidak bisa dilakukan `integration_test`.
5. Mengapa Pigeon lebih aman daripada `MethodChannel` manual?

## 🏠 Tugas Rumah (PR)

1. Naikkan coverage non-generate ke **≥ 70%** (lampirkan `lcov --summary`); prioritaskan `CartSyncService` (sukses, `DioException`, dan pemanggilan saat sedang berjalan).
2. Tambahkan implementasi **Swift** untuk `DeviceApi` (Pigeon `swiftOut`) — atau jelaskan di README mengapa iOS ditunda.
3. Selesaikan `docs/performance-report.md`.
