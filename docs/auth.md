# Authentication dengan Flutter

## **GUIDE LATIHAN: Implementasi Login & Authentication di Flutter**

### 🎯 **Tujuan Pembelajaran**

Peserta dapat:

* Memahami konsep authentication menggunakan JWT (JSON Web Token)
* Implementasi login menggunakan API dari DummyJSON
* Menyimpan token dengan secure storage
* Membuat sistem logout dan refresh token
* Mengelola authentication state dalam aplikasi

---

## 🧩 **1. Persiapan Awal Proyek**

### Langkah 1 — Buat Project Baru

Buka terminal, lalu jalankan:

```bash
flutter create flutter_auth_app
cd flutter_auth_app
code .
```

---

### Langkah 2 — Tambahkan Dependencies

Edit file `pubspec.yaml`, tambahkan:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
  flutter_secure_storage: ^9.0.0
  provider: ^6.1.1
```

Simpan file, lalu jalankan di terminal:

```bash
flutter pub get
```

> 💡 *`flutter_secure_storage` digunakan untuk menyimpan token secara aman, dan `provider` untuk state management.*

---

## 📦 **2. Membuat Struktur Folder**

Buat folder berikut di dalam `lib/`:

```
lib/
 ┣ models/
 ┣ services/
 ┣ providers/
 ┗ pages/
```

---

## 🧠 **3. Membuat Model Data**

### User Model

Buat file: `lib/models/user_model.dart`

```dart
class UserModel {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String gender;
  final String image;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.image,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      gender: json['gender'] ?? '',
      image: json['image'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'image': image,
    };
  }
}
```

### Auth Response Model

Buat file: `lib/models/auth_response_model.dart`

```dart
import 'user_model.dart';

class AuthResponseModel {
  final UserModel user;
  final String accessToken;
  final String refreshToken;

  AuthResponseModel({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      user: UserModel.fromJson(json),
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
    );
  }
}
```

---

## 🔐 **4. Membuat Secure Storage Service**

Buat file: `lib/services/storage_service.dart`

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  // Keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  // Save tokens
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  // Get access token
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  // Get refresh token
  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  // Delete all tokens (logout)
  static Future<void> deleteTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  // Check if user is logged in
  static Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
```

---

## 🌐 **5. Membuat Authentication Service**

Buat file: `lib/services/auth_service.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

class AuthService {
  static const String baseUrl = 'https://dummyjson.com';

  // Login
  static Future<AuthResponseModel> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': password,
        'expiresInMins': 30,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AuthResponseModel.fromJson(data);
    } else {
      throw Exception('Login gagal. Periksa username dan password Anda.');
    }
  }

  // Get current user
  static Future<UserModel> getCurrentUser(String accessToken) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return UserModel.fromJson(data);
    } else {
      throw Exception('Gagal mendapatkan data user');
    }
  }

  // Refresh token
  static Future<AuthResponseModel> refreshToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'refreshToken': refreshToken,
        'expiresInMins': 30,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AuthResponseModel.fromJson(data);
    } else {
      throw Exception('Gagal refresh token');
    }
  }
}
```

---

## 🎯 **6. Membuat Auth Provider (State Management)**

Buat file: `lib/providers/auth_provider.dart`

```dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/auth_response_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  // Login
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final authResponse = await AuthService.login(
        username: username,
        password: password,
      );

      // Save tokens
      await StorageService.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );

      _user = authResponse.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Check if user is logged in
  Future<void> checkAuthStatus() async {
    final hasToken = await StorageService.hasToken();
    if (hasToken) {
      final token = await StorageService.getAccessToken();
      if (token != null) {
        try {
          _user = await AuthService.getCurrentUser(token);
          notifyListeners();
        } catch (e) {
          // Token invalid, logout
          await logout();
        }
      }
    }
  }

  // Logout
  Future<void> logout() async {
    await StorageService.deleteTokens();
    _user = null;
    notifyListeners();
  }
}
```

---

## 🖼️ **7. Membuat Halaman Login**

Buat file: `lib/pages/login_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(
        _usernameController.text,
        _passwordController.text,
      );

      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Login gagal'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo or Icon
                  const Icon(
                    Icons.lock_outline,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Silakan login untuk melanjutkan',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Username field
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Username tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Login button
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      return ElevatedButton(
                        onPressed: authProvider.isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: authProvider.isLoading
                            ? const CircularProgressIndicator()
                            : const Text(
                                'Login',
                                style: TextStyle(fontSize: 16),
                              ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Demo credentials
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📝 Demo Credentials:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text('Username: emilys'),
                        Text('Password: emilyspass'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 🏠 **8. Membuat Halaman Home (Setelah Login)**

Buat file: `lib/pages/home_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Profile Image
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage(user.image),
                  ),
                  const SizedBox(height: 24),

                  // User Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Profile Information',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.person,
                            'Name',
                            '${user.firstName} ${user.lastName}',
                          ),
                          _buildInfoRow(
                            Icons.account_circle,
                            'Username',
                            user.username,
                          ),
                          _buildInfoRow(
                            Icons.email,
                            'Email',
                            user.email,
                          ),
                          _buildInfoRow(
                            Icons.wc,
                            'Gender',
                            user.gender,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 🚀 **9. Setup Main Application**

Edit `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Flutter Auth Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Check auth status when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isAuthenticated) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}
```

---

## 🧪 **10. Testing Aplikasi**

Jalankan aplikasi:

```bash
flutter run
```

### Credentials untuk Testing:

Gunakan user dari [dummyjson.com/users](https://dummyjson.com/users):

| Username | Password |
|----------|----------|
| emilys | emilyspass |
| michaelw | michaelwpass |
| sophiab | sophiabpass |

---

## 🎓 **11. Tugas Latihan Tambahan (Challenge)**

| Level | Tugas | Petunjuk |
|-------|-------|----------|
| 🟢 Dasar | Tambahkan fitur "Remember Me" | Gunakan SharedPreferences untuk menyimpan pilihan user |
| 🟡 Menengah | Implementasi refresh token otomatis | Tangkap error 401 dan panggil refresh token |
| 🔵 Lanjutan | Tambahkan biometric authentication | Gunakan package `local_auth` |

---

## 📚 **Konsep Penting**

### JWT (JSON Web Token)
- Token berbasis JSON untuk autentikasi
- Terdiri dari: Header, Payload, Signature
- Tidak perlu menyimpan session di server

### Secure Storage
- Menyimpan data sensitif dengan enkripsi
- Lebih aman dari SharedPreferences
- Cocok untuk token, password, dll

### State Management
- Provider memudahkan sharing state antar widget
- ChangeNotifier untuk notifikasi perubahan state
- Consumer untuk rebuild widget otomatis

---

## 🔒 **Best Practices**

1. ✅ Selalu gunakan HTTPS untuk API
2. ✅ Simpan token di secure storage
3. ✅ Implementasi refresh token
4. ✅ Handle error dengan baik
5. ✅ Logout ketika token expired
6. ❌ Jangan simpan password
7. ❌ Jangan log token di console (production)

---
