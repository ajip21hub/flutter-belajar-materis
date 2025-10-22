

## **GUIDE LATIHAN: Membuat Aplikasi Flutter Grid User dari API**

### 🎯 **Tujuan Pembelajaran**

Peserta dapat:

* Menggunakan package `http` untuk mengambil data dari API publik.
* Membuat model data (`UserModel`) sesuai struktur JSON.
* Menampilkan data dalam bentuk **GridView** dengan desain sederhana.
* Memahami alur kerja `FutureBuilder` untuk menangani data asynchronous.

---

## 🧩 **1. Persiapan Awal Proyek**

### Langkah 1 — Buat Project Baru

Buka terminal, lalu jalankan:

```bash
flutter create user_grid_app
cd user_grid_app
code .
```

> 💡 *Jika menggunakan VS Code, pastikan Flutter SDK sudah terpasang.*

---

### Langkah 2 — Tambahkan Dependensi HTTP

Edit file `pubspec.yaml`, tambahkan:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
```

Simpan file, lalu jalankan di terminal:

```bash
flutter pub get
```

---

## 📦 **2. Membuat Struktur Folder**

Buat folder berikut di dalam `lib/`:

```
lib/
 ┣ models/
 ┣ services/
 ┗ pages/
```

---

## 🧠 **3. Membuat Model Data (UserModel)**

Buat file baru:
`lib/models/user_model.dart`

Isi dengan:

```dart
class UserModel {
  final int id;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String city;
  final String phone;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.city,
    required this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final name = json['name'] ?? {};
    final address = json['address'] ?? {};

    return UserModel(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      firstName: name['firstname'] ?? '',
      lastName: name['lastname'] ?? '',
      city: address['city'] ?? '',
      phone: json['phone'] ?? '',
    );
  }
}
```

---

## 🌐 **4. Membuat API Service**

Buat file:
`lib/services/api_service.dart`

Isi:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class ApiService {
  static const String baseUrl = 'https://fakestoreapi.com';

  static Future<List<UserModel>> getUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/users'));

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((u) => UserModel.fromJson(u)).toList();
    } else {
      throw Exception('Gagal memuat data pengguna');
    }
  }
}
```

> 💬 *Tujuan: Memahami cara mengambil data dari REST API dan mengubahnya menjadi list of object (`UserModel`).*

---

## 🖼️ **5. Membuat Halaman GridView**

Buat file:
`lib/pages/user_grid_page.dart`

Isi dengan:

```dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class UserGridPage extends StatefulWidget {
  const UserGridPage({super.key});

  @override
  State<UserGridPage> createState() => _UserGridPageState();
}

class _UserGridPageState extends State<UserGridPage> {
  late Future<List<UserModel>> usersFuture;

  @override
  void initState() {
    super.initState();
    usersFuture = ApiService.getUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Grid'),
      ),
      body: FutureBuilder<List<UserModel>>(
        future: usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          final users = snapshot.data ?? [];

          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.2,
            ),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        child: Text(
                          user.firstName.isNotEmpty
                              ? user.firstName[0]
                              : user.username[0].toUpperCase(),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${user.firstName} ${user.lastName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.city,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

---

## 🚀 **6. Jalankan Aplikasi**

Edit `lib/main.dart` menjadi:

```dart
import 'package:flutter/material.dart';
import 'pages/user_grid_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'User Grid Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const UserGridPage(),
    );
  }
}
```

Lalu jalankan:

```bash
flutter run
```

> 💥 *Jika berhasil, akan tampil grid dengan daftar user dari API `https://fakestoreapi.com/users`.*

---

## 🧪 **7. Tugas Latihan Tambahan (Challenge)**

Untuk memperdalam materi, peserta bisa mencoba:

| Level       | Tugas                                                         | Petunjuk                                                         |
| ----------- | ------------------------------------------------------------- | ---------------------------------------------------------------- |
| 🟢 Dasar    | Tambahkan background color berbeda untuk setiap kartu user    | Gunakan `Colors.primaries[index % Colors.primaries.length]`      |
| 🟡 Menengah | Tambahkan tombol “Reload” di AppBar untuk memanggil ulang API | Gunakan `setState(() { usersFuture = ApiService.getUsers(); });` |
| 🔵 Lanjutan | Tambahkan fitur pencarian user berdasarkan nama depan         | Gunakan `TextField` dan `ListView.builder` dengan filter string  |

---


