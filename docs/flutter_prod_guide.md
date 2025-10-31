# Flutter Production Deployment Guide

## 📋 Daftar Isi
1. [Pengenalan](#pengenalan)
2. [Tahap Pre-Development](#tahap-pre-development)
3. [Tahap Development](#tahap-development)
4. [Tahap Pre-Production](#tahap-pre-production)
5. [Build dan Optimization](#build-dan-optimization)
6. [Testing](#testing)
7. [Security & Compliance](#security--compliance)
8. [Deployment](#deployment)
9. [Post-Release Monitoring](#post-release-monitoring)
10. [Automation Scripts](#automation-scripts)

---

## Pengenalan

Panduan ini mencakup semua aspek yang perlu diperiksa sebelum dan sesudah mengembangkan Flutter app untuk production. Ini dirancang khusus untuk solo developer yang ingin automation dan scalability.

**Estimasi waktu persiapan production:** 2-3 minggu sebelum release

---

## 📌 Tahap Pre-Development

### 1. Setup Environment dan Configuration

```bash
# Install dependencies
flutter pub global activate flutterfire_cli
flutter pub global activate fastlane

# Setup flavors untuk multiple environments
flutter create --template=app --project-name=myapp --org=com.example
```

### 2. Version Management
- **Semantic Versioning:** `MAJOR.MINOR.PATCH+BUILD`
- **pubspec.yaml:**
  ```yaml
  version: 1.0.0+1
  # 1.0.0 adalah version code untuk user
  # +1 adalah build number untuk app store
  ```

### 3. Environment Configuration
- **Development:** Localhost/dev API, Debug logging enabled
- **Staging:** Production-like environment, Full logging
- **Production:** Real API, Minimal logging, Error tracking only

---

## 🚀 Tahap Development

### 1. Code Structure dan Best Practices

```
lib/
├── config/              # Environment configurations
├── models/              # Data models, freezed classes
├── services/            # API, Firebase, storage services
├── providers/           # State management (Riverpod/Provider)
├── screens/             # UI screens
├── widgets/             # Reusable widgets
├── utils/               # Helper functions, extensions
└── main.dart           # Entry point

test/
├── models/              # Model tests
├── services/            # Service tests
└── widgets/             # Widget tests

integration_test/
└── app_test.dart       # Integration tests
```

### 2. Logging Configuration

```dart
// lib/utils/logger.dart
import 'package:logger/logger.dart';

class AppLogger {
  static final logger = Logger(
    printer: PrettyPrinter(),
    level: kDebugMode ? Level.debug : Level.error,
  );

  static void info(String msg) => logger.i(msg);
  static void error(String msg, [dynamic error, StackTrace? st]) {
    logger.e(msg, error: error, stackTrace: st);
  }
}

// Usage
AppLogger.info('User logged in');
AppLogger.error('Failed to fetch data', exception, stackTrace);
```

### 3. Error Handling

```dart
// lib/services/error_handler.dart
class AppException implements Exception {
  final String message;
  final dynamic originalException;
  final StackTrace? stackTrace;

  AppException({
    required this.message,
    this.originalException,
    this.stackTrace,
  });

  @override
  String toString() => message;
}

// Usage with try-catch
try {
  await fetchData();
} catch (e, st) {
  AppLogger.error('Failed to fetch', e, st);
  rethrow;
}
```

### 4. State Management (Contoh dengan Riverpod)

```dart
// lib/providers/app_provider.dart
import 'package:riverpod/riverpod.dart';

final appStateProvider = StateNotifierProvider<AppNotifier, AppState>(
  (ref) => AppNotifier(),
);

class AppNotifier extends StateNotifier<AppState> {
  AppNotifier() : super(const AppState.initial());

  Future<void> initialize() async {
    state = const AppState.loading();
    try {
      // Initialization logic
      state = const AppState.success();
    } catch (e, st) {
      state = AppState.error(e.toString());
    }
  }
}

sealed class AppState {
  const AppState();
  const factory AppState.initial() = _Initial;
  const factory AppState.loading() = _Loading;
  const factory AppState.success() = _Success;
  const factory AppState.error(String message) = _Error;
}
```

---

## ✅ Tahap Pre-Production

### 1. Code Analysis dan Linting

```bash
# Run analysis
flutter analyze

# Format code
dart format lib/ test/

# Check for issues
dart pub outdated
dart pub audit
```

**Setup `analysis_options.yaml`:**
```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - avoid_empty_else
    - avoid_print
    - always_declare_return_types
    - camel_case_types
    - library_names
    - file_names
    - prefer_final_fields
    - prefer_final_locals
    - use_build_context_synchronously
```

### 2. Testing

```bash
# Unit tests
flutter test test/

# Coverage
flutter test --coverage

# Integration tests
flutter test integration_test/

# Test specific file
flutter test test/models/user_model_test.dart
```

**Minimum Coverage Requirements:**
- Business Logic: ≥90%
- Services: ≥85%
- Widgets: ≥70%
- Overall: ≥80%

### 3. Performance Profiling

```bash
# Profile mode (closest to release)
flutter run --profile

# Using DevTools
flutter pub global activate devtools
flutter pub global run devtools

# Check memory usage
# Open DevTools > Memory tab
# - Monitor heap size
# - Check for memory leaks
# - Test with large datasets
```

**Performance Targets:**
- App startup: < 3 seconds
- Screen transition: 60 FPS (smooth)
- Memory usage: < 150 MB (low-end device)
- Battery impact: < 5% per hour (normal usage)

### 4. Security Audit

```bash
# Check for vulnerable dependencies
dart pub audit

# Verify no hardcoded secrets
grep -r "api_key\|password\|secret" lib/
grep -r "http://" lib/  # Should be https only

# Check permissions
# Android: android/app/src/main/AndroidManifest.xml
# iOS: ios/Runner/Info.plist
```

**Security Checklist:**
- [ ] No debug print statements
- [ ] No hardcoded API keys/URLs
- [ ] HTTPS only for API calls
- [ ] Secure storage for sensitive data (flutter_secure_storage)
- [ ] Input validation on all forms
- [ ] No SQL injection vulnerabilities
- [ ] Proper error messages (no sensitive info)
- [ ] Certificate pinning (if needed)

### 5. App Store Requirements

#### Android - Google Play Store
```bash
# Create upload key (if not exists)
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Configure signing
# android/app/build.gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? 
                file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

**key.properties** (gitignore ini!):
```properties
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
```

#### iOS - Apple App Store
```bash
# Create certificates dan provisioning profiles di:
# https://developer.apple.com/account/resources/certificates/list

# Build configuration
# Ensure in Xcode:
# - Bundle Identifier matches
# - Team ID set
# - Provisioning profile selected
# - Minimum deployment target: iOS 11.0+
```

---

## 🔨 Build dan Optimization

### 1. Build Release Version

```bash
# Clean and prepare
flutter clean
flutter pub get

# Build APK (Android)
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=./symbols

# Build App Bundle (Android - Recommended for Play Store)
flutter build appbundle --release --obfuscate --split-debug-info=./symbols

# Build iOS
flutter build ios --release --obfuscate --split-debug-info=./symbols --no-codesign
```

### 2. App Size Optimization

| Teknik | Pengurangan Ukuran |
|--------|-------------------|
| Split APK per ABI | 30-40% |
| Release mode | 20-30% |
| Tree shaking (obfuscate) | 10-15% |
| Image compression (WebP) | 5-10% |
| Remove unused packages | Varies |
| ProGuard (Android) | 5-10% |

**Tips Optimasi:**
```bash
# Analisis app size
flutter build appbundle --analyze-size

# Remove unused code
# Dalam pubspec.yaml, remove unused packages

# Optimize images
# Gunakan tool: ImageMagick, TinyPNG, atau Squoosh
# Prefer WebP format (smaller than PNG/JPEG)

# Lazy load heavy data
flutter_cache_manager  # Cache images
url_launcher_web      # Remove if not used
```

### 3. Version Management Script

```bash
#!/bin/bash
# scripts/bump_version.sh

VERSION_FILE="VERSION"
PUBSPEC_FILE="pubspec.yaml"

# Read current version
IFS='.' read -r MAJOR MINOR PATCH < "$VERSION_FILE"

# Increment version
MINOR=$((MINOR + 1))
NEW_VERSION="$MAJOR.$MINOR.$PATCH"
BUILD_NUMBER=$(($(date +%s) / 1000))

# Update files
echo "$NEW_VERSION" > "$VERSION_FILE"
sed -i "s/^version: .*/version: $NEW_VERSION+$BUILD_NUMBER/" "$PUBSPEC_FILE"

echo "Version updated to $NEW_VERSION+$BUILD_NUMBER"
```

---

## 🧪 Testing

### 1. Unit Tests

```dart
// test/models/user_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/user.dart';

void main() {
  group('User Model', () {
    test('User creation with valid data', () {
      final user = User(id: '1', name: 'John', email: 'john@example.com');
      expect(user.id, '1');
      expect(user.name, 'John');
    });

    test('User email validation', () {
      expect(
        () => User(id: '1', name: 'John', email: 'invalid-email'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
```

### 2. Widget Tests

```dart
// test/widgets/login_button_test.dart
void main() {
  testWidgets('LoginButton shows loading state', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoginButton(onPressed: null),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

### 3. Integration Tests

```dart
// integration_test/app_test.dart
void main() {
  group('App Integration Tests', () {
    testWidgets('Full login flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Enter credentials
      await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password');

      // Tap login
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verify navigation
      expect(find.byType(HomePage), findsOneWidget);
    });
  });
}
```

### 4. Test Coverage

```bash
# Generate coverage
flutter test --coverage

# View coverage report
# Open coverage/lcov.info atau gunakan tool seperti genhtml
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## 🔒 Security & Compliance

### 1. Firebase Setup untuk Production

```dart
// lib/services/firebase_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp();
    
    // Crashlytics setup
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    
    // Analytics setup
    await FirebaseAnalytics.instance.logAppOpen();
  }
  
  static FirebaseAnalytics getAnalytics() => FirebaseAnalytics.instance;
  static FirebaseCrashlytics getCrashlytics() => FirebaseCrashlytics.instance;
}

// Usage
FirebaseService.getCrashlytics().recordError(exception, stackTrace);
FirebaseService.getAnalytics().logEvent(
  name: 'user_login',
  parameters: {'method': 'email'},
);
```

### 2. Secure Storage

```dart
// lib/services/secure_storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  
  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }
  
  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }
  
  static Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
  }
}

// Never store in SharedPreferences!
// Always use flutter_secure_storage untuk sensitive data
```

### 3. SSL Certificate Pinning

```dart
// lib/services/http_service.dart
import 'package:http/http.dart' as http;

class HttpService {
  static Future<http.Response> get(String url) async {
    final client = http.Client();
    
    try {
      return await client.get(Uri.parse(url));
    } finally {
      client.close();
    }
  }
  
  // Untuk certificate pinning, gunakan package: dio dengan interceptor
  // atau native Android/iOS implementation
}
```

### 4. Dependency Security

```bash
# Audit dependencies untuk vulnerabilities
dart pub audit

# Check for outdated packages
dart pub outdated

# Setup automated checks (GitHub)
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "pub"
    directory: "/"
    schedule:
      interval: "daily"
    open-pull-requests-limit: 10
```

---

## 🚢 Deployment

### 1. Android - Google Play Store

```bash
# Build App Bundle
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=./symbols

# Upload ke Play Store
# 1. Go to Google Play Console
# 2. Create new release
# 3. Upload app-release.aab
# 4. Fill in release notes
# 5. Set staged rollout (5% → 100%)
# 6. Submit for review
```

### 2. iOS - Apple App Store

```bash
# Build iOS release
flutter build ios --release \
  --obfuscate \
  --split-debug-info=./symbols \
  --no-codesign

# Create archive in Xcode
# 1. Open Xcode: open ios/Runner.xcworkspace
# 2. Select "Product" > "Archive"
# 3. Upload to App Store
# 4. Fill metadata and screenshots
# 5. Submit for review
```

### 3. Staged Rollout Strategy

```
Day 1: 5% of users (Monitor crashes)
Day 2: 10% of users
Day 3: 25% of users
Day 4: 50% of users
Day 5+: 100% of users (if stable)

Rollback procedure:
1. Pause rollout immediately
2. Check Firebase Crashlytics
3. Fix critical bugs
4. Release patch version
```

---

## 📊 Post-Release Monitoring

### 1. Firebase Crashlytics Integration

```dart
// Monitor crashes in real-time
FirebaseCrashlytics.instance.recordError(
  exception,
  stackTrace,
  reason: 'User action failed',
  fatal: false,
);

// Custom logging
FirebaseCrashlytics.instance.log('User navigated to screen X');
```

**Dashboard Monitoring:**
- Real-time crash reports
- Crash-free users percentage
- Critical vs non-critical issues
- Device & OS breakdown
- User impact assessment

### 2. Firebase Analytics Setup

```dart
// Track important events
class AnalyticsService {
  static final _analytics = FirebaseAnalytics.instance;
  
  static Future<void> logUserLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }
  
  static Future<void> logPurchase(double amount, String currency) async {
    await _analytics.logPurchase(
      currency: currency,
      value: amount,
    );
  }
  
  static Future<void> logEvent(String name, Map<String, dynamic>? params) async {
    await _analytics.logEvent(name: name, parameters: params);
  }
}

// Usage
AnalyticsService.logEvent('feature_used', {'feature_name': 'search'});
```

### 3. Performance Monitoring

```dart
// lib/services/performance_service.dart
import 'package:firebase_performance/firebase_performance.dart';

class PerformanceService {
  static final _performance = FirebasePerformance.instance;
  
  static Future<void> traceApiCall(String endpoint) async {
    final trace = _performance.newHttpMetric(
      'https://api.example.com$endpoint',
      HttpMethod.Get,
    );
    
    await trace.start();
    
    try {
      // Make API call
      final response = await http.get(Uri.parse('https://api.example.com$endpoint'));
      
      trace.setHttpResponseCode(response.statusCode);
      trace.setResponsePayloadSize(response.bodyBytes.length);
    } finally {
      await trace.stop();
    }
  }
}
```

### 4. Key Metrics to Monitor

| Metrik | Target | Alat |
|--------|--------|------|
| Crash-free rate | > 99% | Firebase Crashlytics |
| Average session | > 5 min | Firebase Analytics |
| User retention (Day 1) | > 40% | Firebase Analytics |
| User retention (Day 7) | > 20% | Firebase Analytics |
| App startup time | < 3 sec | Firebase Performance |
| API response time | < 2 sec | Firebase Performance |
| Battery impact | < 5%/hour | Device monitoring |

---

## 🤖 Automation Scripts

### 1. Pre-Production Check Script

```bash
#!/bin/bash
# scripts/pre_production_check.sh

# Jalankan semua checks sebelum build
flutter clean
flutter pub get --enforce-lockfile
flutter analyze
dart format --set-exit-if-changed lib/
flutter test --coverage
flutter build apk --debug
```

**Usage:**
```bash
chmod +x scripts/pre_production_check.sh
./scripts/pre_production_check.sh
```

### 2. Automated Build Script

```bash
#!/bin/bash
# scripts/build_release.sh

VERSION=${1:-""}
if [ -z "$VERSION" ]; then
  echo "Usage: ./scripts/build_release.sh VERSION"
  exit 1
fi

# Update version
sed -i "s/^version: .*/version: $VERSION/" pubspec.yaml

# Build
flutter clean
flutter pub get
flutter build appbundle --release --obfuscate --split-debug-info=./symbols

# Verify and backup symbols
ls -lh build/app/outputs/bundle/release/app-release.aab
shasum -a 256 build/app/outputs/bundle/release/app-release.aab > build/release.sha256
```

### 3. GitHub Actions CI/CD Pipeline

```yaml
# .github/workflows/flutter_cicd.yml
name: Flutter CI/CD

on:
  push:
    branches: [main, release/**]
  pull_request:
    branches: [main]

jobs:
  analyze_and_test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 'stable'
      
      - run: flutter pub get --enforce-lockfile
      - run: flutter analyze
      - run: dart format --set-exit-if-changed lib/
      - run: flutter test --coverage
      - run: flutter build apk --debug

  build_release:
    needs: analyze_and_test
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      
      - run: |
          flutter pub get
          flutter build appbundle --release \
            --obfuscate \
            --split-debug-info=./symbols
      
      - uses: actions/upload-artifact@v3
        with:
          name: release-bundle
          path: build/app/outputs/bundle/release/app-release.aab
```

---

## 📝 Deployment Checklist Final

```
SEBELUM RELEASE:
☐ Code analysis passed (flutter analyze)
☐ Format check passed (dart format)
☐ Tests passed (flutter test)
☐ Security audit passed (dart pub audit)
☐ Version bumped in pubspec.yaml
☐ CHANGELOG.md updated
☐ App icons and splash screens updated
☐ Screenshots and descriptions ready
☐ Privacy policy link added
☐ Terms of service link added
☐ Firebase projects configured
☐ Signing keys configured
☐ Certificates and provisioning profiles ready

BUILD:
☐ Clean build successful
☐ App size acceptable (< 100 MB)
☐ Symbols file backed up
☐ SHA256 checksum calculated
☐ Tested in release mode
☐ Performance acceptable

RELEASE:
☐ Uploaded to internal testing track
☐ QA team testing complete
☐ Release notes written
☐ Staged rollout configured (5% → 100%)
☐ Monitoring alerts configured
☐ Rollback plan ready
☐ Support team prepared
☐ Launch announcement ready

POST-RELEASE (24 HOURS):
☐ No critical crashes
☐ User retention tracking
☐ Analytics data flowing
☐ No support escalations
☐ Rollout proceeding as planned
```

---

## 🎯 Quick Reference Commands

```bash
# Pre-production checks
flutter clean && flutter pub get --enforce-lockfile
flutter analyze
dart format lib/ test/
flutter test --coverage

# Build release
flutter build appbundle --release --obfuscate --split-debug-info=./symbols

# Verify build
shasum -a 256 build/app/outputs/bundle/release/app-release.aab

# Check performance
flutter run --profile

# Debug obfuscated crashes
flutter symbolize -i stacktrace.txt -d symbols/app.android-arm64.symbols

# Monitor analytics
# firebase analytics dashboard

# Check crashes
# Firebase Crashlytics console
```

---

## 📚 Sumber Referensi

- Flutter Documentation: https://docs.flutter.dev
- Firebase Documentation: https://firebase.google.com/docs
- Google Play Console: https://play.google.com/console
- Apple App Store Connect: https://appstoreconnect.apple.com
- Dart Package Registry: https://pub.dev

---

**Terakhir diupdate:** 31 Oktober 2025

**Dibuat untuk:** Solo Flutter Developers dalam perjalanan ke production.
