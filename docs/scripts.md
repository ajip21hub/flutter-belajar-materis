# 🛠️ Production Build Scripts

Berikut adalah daftar script automation yang tersedia untuk build dan deployment Flutter app ke production.

## 📁 Script Files

### 1. `build_production.sh`
**Deskripsi:** Script untuk build production version dengan optimasi penuh

```bash
# Usage: ./build_production.sh VERSION
./script/build_production.sh 1.0.0
```

**Fitur:**
- ✅ Clean build environment
- ✅ Version bumping otomatis
- ✅ Build dengan obfuscation
- ✅ Split debug info untuk crash reporting
- ✅ SHA256 checksum generation
- ✅ Size analysis

### 2. `pre_production_check.sh`
**Deskripsi:** Script untuk menjalankan semua checks sebelum build

```bash
# Usage: ./pre_production_check.sh
./script/pre_production_check.sh
```

**Fitur:**
- ✅ Flutter analyze
- ✅ Code formatting check
- ✅ Unit test dengan coverage
- ✅ Security audit
- ✅ Dependency validation
- ✅ Debug build verification

### 3. `post_build_verify.sh`
**Deskripsi:** Script untuk verifikasi hasil build

```bash
# Usage: ./post_build_verify.sh [BUILD_PATH]
./script/post_build_verify.sh build/app/outputs/bundle/release/
```

**Fitur:**
- ✅ Build integrity check
- ✅ Size validation
- ✅ Signature verification
- ✅ Performance baseline check
- ✅ Artifact backup

## 🚀 Quick Start

### Build Production Flow:

1. **Pre-production checks:**
   ```bash
   chmod +x script/pre_production_check.sh
   ./script/pre_production_check.sh
   ```

2. **Build production:**
   ```bash
   chmod +x script/build_production.sh
   ./script/build_production.sh 1.0.0
   ```

3. **Post-build verification:**
   ```bash
   chmod +x script/post_build_verify.sh
   ./script/post_build_verify.sh
   ```

## 📋 Script Matrix

| Script | Purpose | Input | Output | Dependencies |
|--------|---------|-------|--------|--------------|
| `pre_production_check.sh` | Quality gates | - | Pass/Fail | Flutter, Dart |
| `build_production.sh` | Build automation | Version | AAB/APK + Symbols | Flutter, Java |
| `post_build_verify.sh` | Build validation | Build path | Verification report | OpenSSL, File tools |

## 🔧 Requirements

**System Requirements:**
- Flutter SDK (stable channel)
- Dart SDK
- Java 11+ (untuk Android build)
- OpenSSL (untuk checksum)
- Git

**Permissions:**
```bash
# Make all scripts executable
chmod +x script/*.sh
```

## 📝 Integration dengan CI/CD

### GitHub Actions Example:
```yaml
- name: Run Pre-production Checks
  run: ./script/pre_production_check.sh

- name: Build Production
  run: ./script/build_production.sh ${{ github.sha }}

- name: Verify Build
  run: ./script/post_build_verify.sh
```

### Local Development:
```bash
# Add to shell profile for easy access
alias flutter-preprod='./script/pre_production_check.sh'
alias flutter-build='./script/build_production.sh'
alias flutter-verify='./script/post_build_verify.sh'
```

## 🐛 Troubleshooting

**Common Issues:**

1. **Permission denied:**
   ```bash
   chmod +x script/*.sh
   ```

2. **Flutter not found:**
   ```bash
   export PATH="$PATH:/path/to/flutter/bin"
   ```

3. **Java version issue:**
   ```bash
   export JAVA_HOME=/path/to/java11
   ```

4. **Build fails on missing symbols:**
   ```bash
   flutter clean
   flutter pub get
   ./script/build_production.sh
   ```

## 📚 Additional Resources

- [Flutter Production Guide](/flutter_prod_guide) - Panduan lengkap production deployment
- [CI/CD Introduction](/ci-cd-introduction) - Konsep CI/CD untuk Flutter
- [Feature Development Template](/feature-development-template) - Template pengembangan fitur

---

**📌 Tip:** Simpan script files di Git repository dan version bersama codebase untuk consistency.