# 📱 MATRIX Mobile App

<div align="center">
  <img src="MATRIX-LOGO-NOBG-292X292.png" width="200" alt="MATRIX Logo"/>
  
  ### SiLAKES MATRIX
  **Manajemen Absensi Terintegrasi dan Remunerasi Insentif eXpert**
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.8+-02569B?logo=flutter)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)](https://dart.dev)
  [![Laravel](https://img.shields.io/badge/Laravel-10+-FF2D20?logo=laravel)](https://laravel.com)
  [![License](https://img.shields.io/badge/License-Proprietary-red)](LICENSE)
</div>

---

## 📖 Deskripsi

**MATRIX Mobile** adalah aplikasi mobile HR & Attendance Management yang komprehensif untuk **Labkesda Sumenep**. Aplikasi ini menggabungkan teknologi modern seperti Face Recognition, GPS Tracking, dan Real-time Data Processing untuk menghadirkan sistem absensi yang **akurat, aman, dan mudah digunakan**.

Dibangun dengan **Flutter** untuk cross-platform experience dan terintegrasi dengan backend **Laravel API**, MATRIX Mobile menjadi solusi digital yang efisien untuk manajemen kehadiran karyawan.

---

## ✨ Fitur Utama

### 🎭 1. **Face Attendance dengan AI**
- **Face Detection** menggunakan Google ML Kit
- **Liveness Detection** - Blink to Capture (kedipkan mata 2x)
- **Anti-Spoofing** - Validasi orientasi wajah
- **Text-to-Speech** - Panduan suara interaktif
  - "Halo [Nama], hadapkan wajah Anda ke kamera"
  - "Kedipkan mata Anda"
  - "Terimakasih"
- **Photo Capture** otomatis setelah validasi

### 📍 2. **Location-Based Attendance**
- **GPS Tracking** real-time
- **Geofencing** - Validasi radius lokasi
- **Multiple Locations** - Support banyak titik absensi
- **Distance Calculation** - Tampilan jarak dari lokasi
- **Interactive Map** - OpenStreetMap dengan marker & radius
- **WFA Mode** (Work From Anywhere) - Bebas lokasi untuk user tertentu

### ⏰ 3. **Attendance Management**
- **Dual Mode**:
  - **Fixed Mode** - Jadwal ketat dengan window time
  - **Flexi Mode** - Fleksibel dengan delay protection
- **Check-In/Check-Out** dengan foto wajah
- **Locked Mode** - Countdown otomatis di luar jam kerja
- **Real-time Validation** - Window time untuk check-in/out
- **Cross-Midnight Support** - Handle shift malam (lintas hari)
- **Late Detection** - Kalkulasi keterlambatan otomatis
- **Penalty System** - Denda keterlambatan terintegrasi

### 📊 4. **Dashboard Real-time**
- **Progress Kerja Hari Ini**:
  - ⏱️ Timer real-time (HH:MM:SS) berjalan setiap detik
  - 📈 Progress bar bergerak smooth
  - 📊 Persentase update otomatis
  - 🎨 Warna dinamis (Warning → Info → Success)
- **Shift Card** - Info shift hari ini dengan window time
- **Quick Stats** - Hadir, Terlambat, Tidak Hadir
- **Monthly Performance**:
  - Total jam kerja bulan ini
  - Persentase kehadiran
  - Total poin dan denda
- **Tomorrow Schedule** - Preview jadwal besok

### 📅 5. **Schedule Management**
- **My Schedule** - Jadwal personal dengan filter
- **Calendar View** - Visual jadwal bulanan
- **Shift Details** - Informasi lengkap setiap shift
- **Color-Coded Shifts**:
  - 🌅 Pagi (ASN) - Biru
  - 🌞 Siang (Non-ASN) - Orange
  - 🌙 Malam - Ungu
- **Swap Request** - Request tukar shift (upcoming)

### 📝 6. **Leave Management**
- **Pengajuan Izin/Cuti**:
  - Izin Sakit (dengan file pendukung)
  - Cuti Tahunan
  - Izin Pribadi
- **File Upload** - Lampiran dokumen (PDF, JPG, PNG)
- **File Preview** - Lihat file sebelum upload
- **Status Tracking**:
  - ⏳ Pending - Menunggu approval
  - ✅ Approved - Disetujui
  - ❌ Rejected - Ditolak
- **Leave History** - Riwayat pengajuan

### 📈 7. **Performance & Points**
- **Point System** - Reward kehadiran
- **Penalty Tracking** - Denda keterlambatan
- **Work Hours** - Total jam kerja bulanan
- **Attendance Rate** - Persentase kehadiran
- **Performance Chart** - Grafik performa (upcoming)

### 🔐 8. **Security & Authentication**
- **Device Activation** - One device per user
- **Activation Code** - 6 digit OTP via email
- **Secure Storage** - Encrypted data dengan flutter_secure_storage
- **Auto-Logout** - Proteksi inaktivitas
- **PIN Protection** - 6 digit PIN untuk keamanan tambahan
- **Biometric Auth** - Fingerprint/Face unlock (upcoming)
- **Token-based Auth** - Laravel Sanctum

### 👤 9. **User Profile**
- **Profile Display**:
  - Foto profil
  - Nama lengkap
  - Jabatan
  - Email
  - Username
- **Attendance Mode Badge**:
  - 📌 Fixed - Jadwal tetap
  - 🔄 Flexi - Fleksibel
- **Settings**:
  - Change Password
  - Logout
  - About App

### 🎨 10. **Modern UI/UX**
- **Material Design 3**
- **Futuristic Bottom Navigation** - Animasi smooth
- **Glassmorphism Effects**
- **Dark Mode Support** (upcoming)
- **Responsive Layout** - Adaptif semua ukuran layar
- **Shimmer Loading** - Loading state yang elegan
- **Custom Animations** - Smooth transitions
- **Snackbar Notifications** - Toast message di atas

---

## 🏗️ Arsitektur Aplikasi

### Frontend (Flutter)
```
lib/
├── core/
│   ├── constants/          # App constants
│   ├── theme/             # Theme & colors
│   ├── utils/             # Utility functions
│   └── widgets/           # Reusable widgets
├── features/
│   ├── auth/              # Authentication
│   │   ├── data/         # Models & repositories
│   │   └── presentation/ # UI & providers
│   ├── attendance/        # Attendance features
│   │   ├── data/
│   │   └── presentation/
│   ├── dashboard/         # Dashboard & home
│   ├── schedule/          # Schedule management
│   ├── leave/             # Leave requests
│   └── profile/           # User profile
└── main.dart
```

### Backend (Laravel API)
```
app/
├── Http/Controllers/Matrix/
│   ├── AttendanceController.php
│   ├── ScheduleController.php
│   └── Mobile/
│       └── MobileMatrixController.php
├── Models/
│   ├── User.php
│   ├── Attendance.php
│   ├── Schedule.php
│   ├── Shift.php
│   └── AttendanceLocation.php
└── Services/Matrix/
    ├── GeolocationService.php
    └── CalculationService.php
```

---

## 🛠️ Tech Stack

### Frontend
- **Framework**: Flutter 3.8+
- **Language**: Dart 3.0+
- **State Management**: Riverpod
- **HTTP Client**: Dio
- **Navigation**: Go Router
- **Storage**: flutter_secure_storage
- **ML**: google_ml_kit_face_detection
- **Maps**: flutter_map, latlong2
- **Location**: geolocator
- **Camera**: camera
- **TTS**: flutter_tts
- **Permissions**: permission_handler
- **Image**: image_picker, image_cropper
- **File**: file_picker
- **Date**: intl

### Backend
- **Framework**: Laravel 10+
- **PHP**: 8.1+
- **Database**: MySQL/MariaDB
- **Authentication**: Laravel Sanctum
- **Email**: SMTP (Gmail)
- **Queue**: Redis (optional)
- **Storage**: Local/S3

### DevOps
- **Version Control**: Git
- **API Testing**: Postman
- **Build**: Gradle (Android), Xcode (iOS)

---

## 🚀 Installation & Setup

### Prerequisites
- Flutter SDK 3.8+
- Dart SDK 3.0+
- Android Studio / VS Code
- PHP 8.1+
- Composer
- MySQL/MariaDB

### Frontend Setup

```bash
# 1. Clone repository
git clone <repository-url>
cd matrix

# 2. Install dependencies
flutter pub get

# 3. Generate code (jika ada)
flutter pub run build_runner build --delete-conflicting-outputs

# 4. Configure API endpoint
# Edit lib/core/constants/app_constants.dart
# Set baseUrl ke API Laravel Anda

# 5. Run app
flutter run
```

### Backend Setup

```bash
# 1. Navigate to backend directory
cd api-administrasi-labkesda

# 2. Install dependencies
composer install

# 3. Configure environment
cp .env.example .env
php artisan key:generate

# 4. Configure database (.env)
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=silakes_db
DB_USERNAME=root
DB_PASSWORD=

# 5. Run migrations
php artisan migrate

# 6. Seed data (optional)
php artisan db:seed

# 7. Start server
php artisan serve
```

---

## 📱 User Flow

### 1. Aktivasi Device (First Time)
```
1. Buka aplikasi
2. Masukkan Username/Email
3. Request Activation Code
4. Cek email untuk 6-digit code
5. Masukkan code
6. Device teraktivasi ✅
```

### 2. Login
```
1. Masukkan Username & Password
2. Login berhasil
3. Navigate ke Dashboard
```

### 3. Absensi Check-In
```
1. Tap tombol "Absen Masuk"
2. Kamera terbuka dengan oval guide
3. Posisikan wajah di dalam oval
4. TTS: "Halo [Nama], hadapkan wajah ke kamera"
5. Wajah terdeteksi
6. TTS: "Kedipkan mata Anda"
7. Kedipkan mata 2x
8. Foto ter-capture otomatis
9. Validasi lokasi GPS
10. TTS: "Terimakasih"
11. Data tersimpan ✅
12. Kembali ke Dashboard
```

### 4. Monitor Progress Kerja
```
1. Buka Home Tab
2. Lihat card "Progress Kerja Hari Ini"
3. Timer berjalan real-time (02:35:47)
4. Progress bar bergerak (45% → 46%)
5. Target dari database shift
```

### 5. Absensi Check-Out
```
1. Tap tombol "Absen Pulang"
2. Ulangi proses face detection
3. Data check-out tersimpan
4. Durasi kerja dihitung otomatis
5. Poin & penalty diproses
```

### 6. Pengajuan Izin
```
1. Navigate ke tab Kinerja
2. Tap "Ajukan Izin"
3. Pilih jenis izin
4. Isi form (tanggal, alasan)
5. Upload file pendukung (optional)
6. Submit
7. Menunggu approval
```

---

## 🎯 User Roles & Modes

### Attendance Mode

#### 1. Fixed Mode (Karyawan Tetap)
- Jadwal ketat dengan window time
- Check-in: 08:00 - 09:00
- Check-out: 16:00 - 17:00
- Late penalty applies
- Locked mode di luar window

#### 2. Flexi Mode (Karyawan Fleksibel)
- Bebas waktu check-in
- Delay 5 menit sebelum bisa check-out
- No late penalty
- Poin flat: 85 per attendance

### Location Mode

#### 1. Location-Based (Default)
- Harus di dalam radius lokasi
- Validasi GPS coordinates
- Support multiple locations
- Distance calculation

#### 2. WFA Mode (Work From Anywhere)
- Bebas lokasi
- Tidak validasi GPS
- Khusus untuk user tertentu
- Data lokasi tetap disimpan

---

## 🔒 Security Features

1. **Device Activation** - One device one user
2. **Encrypted Storage** - Secure local data
3. **Token Authentication** - Sanctum tokens
4. **API Rate Limiting** - Prevent abuse
5. **Photo Verification** - Face attendance proof
6. **Geolocation Validation** - Location-based security
7. **Liveness Detection** - Blink verification
8. **Session Management** - Auto-logout
9. **PIN Protection** - Additional security layer
10. **HTTPS Only** - Secure data transmission

---

## 📊 Performance Optimization

1. **Lazy Loading** - Load data on demand
2. **Caching** - Reduce API calls
3. **Image Compression** - Optimize photo upload
4. **Debouncing** - Prevent rapid requests
5. **Pagination** - Large dataset handling
6. **Real-time Updates** - Timer efficiency
7. **Memory Management** - Proper dispose
8. **Background Processing** - Queue jobs (backend)

---

## 🐛 Known Issues & Solutions

### Issue: TTS terpotong saat navigate
**Solution**: Tambahkan delay 1.5 detik sebelum navigate ✅

### Issue: Progress tidak realtime
**Solution**: Implementasi Timer update setiap detik ✅

### Issue: Memory leak pada Timer
**Solution**: Cancel timer di dispose() ✅

### Issue: Rincian Harian menampilkan "0.1 jam" yang membingungkan
**Solution**: Format durasi ke "X jam Y menit" dengan label "Durasi Kerja" yang jelas ✅
- Tambah label konteks "Durasi Kerja" / "Belum absen"
- Layout 2 section dengan detail box terpisah
- Badge desimal untuk referensi cepat
- Icon jam untuk visual cue

---

## 🚀 Production Build

### Quick Build (APK for Testing)

```bash
# Clean & build APK
flutter clean
flutter pub get
flutter build apk --release --split-per-abi

# Output: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### Production Build (AAB for Play Store)

```bash
# Build Android App Bundle
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### First Time Setup (Signing)

1. **Generate Keystore:**
```bash
keytool -genkey -v -keystore D:\keystore\matrix-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias matrix
```

2. **Create `android/key.properties`:**
```properties
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=matrix
storeFile=D:/keystore/matrix-release-key.jks
```

3. **Update `android/app/build.gradle`** - Add signing configuration

📖 **Detailed Guide:** [PRODUCTION_BUILD_GUIDE.md](PRODUCTION_BUILD_GUIDE.md)  
⚡ **Quick Reference:** [QUICK_BUILD.md](QUICK_BUILD.md)

---

## 🔮 Upcoming Features

- [ ] Dark Mode
- [ ] Biometric Authentication (Fingerprint/Face ID)
- [ ] Push Notifications
- [ ] Offline Mode
- [ ] Performance Chart & Analytics
- [ ] Swap Shift Request
- [ ] Overtime Tracking
- [ ] Multi-language Support
- [ ] Export Reports (PDF)
- [ ] In-App Chat

---

## 📞 Support & Contact

**Developer**: SiLAKES Development Team  
**Organization**: Labkesda Sumenep  
**Email**: support@silakes.id  
**Version**: 1.0.0  
**Last Updated**: 10 Januari 2026

---

## 📄 License

Proprietary - © 2026 SiLAKES Labkesda Sumenep. All rights reserved.

---

<div align="center">
  
### Made with ❤️ using Flutter & Laravel
  
**MATRIX Mobile** - Transforming HR Management

</div>
