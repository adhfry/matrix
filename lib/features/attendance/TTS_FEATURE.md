# Feature: Text-to-Speech (TTS) untuk Face Attendance

## 🎤 Fitur Baru

Menambahkan voice guidance dengan suara wanita yang ceria, lucu, dan imut untuk membantu user saat face attendance.

## 📦 Dependencies

```yaml
dependencies:
  flutter_tts: ^4.2.5
```

## 🎯 Use Cases

### 1. **Welcome Message (Saat Kamera Terbuka)**
```
🔊 "Halo {nama panggilan}, hadapkan wajah anda ke kamera"
```

**Trigger:**
- Saat kamera berhasil diinisialisasi
- Hanya sekali per session (menggunakan flag `_hasSpokeWelcome`)

**Example:**
- Full name: "AHDA FIRLY BARORI"
- First name: "AHDA"
- TTS: "Halo AHDA, hadapkan wajah anda ke kamera"

### 2. **Success Message (Saat Berhasil Absen)**
```
🔊 "Terimakasih"
```

**Trigger:**
- Setelah check-in berhasil
- Setelah check-out berhasil
- Sebelum navigate back

## 🔧 Implementation

### File Modified: `face_attendance_page.dart`

#### 1. Import Package
```dart
import 'package:flutter_tts/flutter_tts.dart';
```

#### 2. Add State Variables
```dart
// Text-to-Speech
final FlutterTts _flutterTts = FlutterTts();
bool _hasSpokeWelcome = false;
```

#### 3. Initialize TTS
```dart
Future<void> _initTts() async {
  try {
    // Set language to Indonesian
    await _flutterTts.setLanguage("id-ID");
    
    // Set voice properties untuk suara wanita yang ceria
    await _flutterTts.setSpeechRate(0.5); // Kecepatan normal
    await _flutterTts.setVolume(1.0); // Volume maksimal
    await _flutterTts.setPitch(1.2); // Pitch lebih tinggi untuk suara lebih imut
    
    // Set voice (untuk Android)
    if (Platform.isAndroid) {
      await _flutterTts.setVoice({"name": "id-id-x-ida-local", "locale": "id-ID"});
    }
    
    print("✅ TTS initialized successfully");
  } catch (e) {
    print("❌ TTS initialization error: $e");
  }
}
```

#### 4. TTS Functions
```dart
Future<void> _speak(String text) async {
  try {
    await _flutterTts.speak(text);
    print("🔊 TTS Speaking: $text");
  } catch (e) {
    print("❌ TTS speak error: $e");
  }
}

Future<void> _speakWelcome() async {
  if (_hasSpokeWelcome) return;
  
  _hasSpokeWelcome = true;
  
  // Get nama panggilan (first name)
  final fullName = widget.config.user.name;
  final firstName = fullName.split(' ').first;
  
  await _speak("Halo $firstName, hadapkan wajah anda ke kamera");
}

Future<void> _speakSuccess() async {
  await _speak("Terimakasih");
}
```

#### 5. Call Welcome on Camera Init
```dart
if (mounted) {
  setState(() => _isCameraInitialized = true);
  await _cameraController!.startImageStream(_processCameraImage);
  
  // Speak welcome message setelah kamera ready ✅
  _speakWelcome();
}
```

#### 6. Call Success on Submit
```dart
if (mounted) {
  // Speak success before navigating ✅
  await _speakSuccess();
  
  Navigator.pop(context, true);
  SnackBarHelper.showSuccess(
    context,
    isCheckOut ? 'Check-out berhasil!' : 'Check-in berhasil!',
  );
}
```

#### 7. Cleanup on Dispose
```dart
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _cameraController?.dispose();
  _faceDetector.close();
  _flutterTts.stop(); // ✅ Stop TTS
  _mapController.dispose();
  _positionStreamSubscription?.cancel();
  _countdownTimer?.cancel();
  super.dispose();
}
```

## 🎨 Voice Configuration

### Voice Properties:
```dart
setLanguage("id-ID")       // Bahasa Indonesia
setSpeechRate(0.5)         // Kecepatan normal (tidak terlalu cepat/lambat)
setVolume(1.0)             // Volume maksimal
setPitch(1.2)              // Pitch tinggi untuk suara lebih imut & ceria
```

### Voice Selection (Android):
```dart
setVoice({
  "name": "id-id-x-ida-local",  // Indonesian female voice
  "locale": "id-ID"
})
```

## 📱 User Experience

### Flow 1: Check-In Normal
```
1. User buka halaman face attendance
2. Kamera loading...
3. Kamera ready ✅
4. 🔊 "Halo AHDA, hadapkan wajah anda ke kamera"
5. User posisikan wajah
6. Face detected → Blink 2x
7. Submit check-in
8. 🔊 "Terimakasih"
9. Navigate back dengan snackbar success
```

### Flow 2: Check-Out Normal
```
1. User buka halaman face attendance (sudah check-in)
2. Kamera ready
3. 🔊 "Halo AHDA, hadapkan wajah anda ke kamera"
4. User posisikan wajah
5. Face detected → Blink 2x
6. Submit check-out
7. 🔊 "Terimakasih"
8. Navigate back dengan snackbar success
```

### Flow 3: Re-enter Page (Welcome Only Once)
```
1. User buka halaman
2. 🔊 "Halo AHDA..." (first time)
3. User keluar (back)
4. User masuk lagi
5. 🔊 (silent - tidak speak lagi karena _hasSpokeWelcome = true)
```

## 🎭 Voice Characteristics

### Target Voice:
- **Gender**: Female (Wanita)
- **Tone**: Ceria, lucu, imut
- **Speed**: Normal (0.5)
- **Pitch**: Tinggi (1.2) - untuk kesan lebih imut
- **Volume**: Maksimal (1.0)

### Why These Settings?
1. **Pitch 1.2**: Suara lebih tinggi = lebih imut dan friendly
2. **Speed 0.5**: Tidak terlalu cepat, jelas didengar
3. **Volume 1.0**: Terdengar jelas di lingkungan kantor

## 🧪 Testing

### Test 1: Welcome Message
```
1. Buka face attendance page
2. Wait for camera init
3. Expected: 🔊 "Halo {FirstName}, hadapkan wajah anda ke kamera"
4. Check logs: "🔊 TTS Speaking: Halo ..."
```

### Test 2: Success Message
```
1. Complete face detection
2. Submit attendance
3. Expected: 🔊 "Terimakasih"
4. Check logs: "🔊 TTS Speaking: Terimakasih"
5. Navigate back
```

### Test 3: Welcome Only Once
```
1. Buka page → Hear welcome ✅
2. Back
3. Buka lagi → No welcome (silent) ✅
4. Check: _hasSpokeWelcome should be true
```

### Test 4: Different Names
```
- "AHDA FIRLY BARORI" → "Halo AHDA..."
- "JOHN DOE SMITH" → "Halo JOHN..."
- "SITI" → "Halo SITI..."
- "MUHAMMAD RIZKI" → "Halo MUHAMMAD..."
```

## 🐛 Error Handling

### TTS Init Failure:
```dart
try {
  await _flutterTts.setLanguage("id-ID");
  // ... other settings
} catch (e) {
  print("❌ TTS initialization error: $e");
  // App tetap berjalan, hanya TTS yang tidak aktif
}
```

### Speak Failure:
```dart
try {
  await _flutterTts.speak(text);
} catch (e) {
  print("❌ TTS speak error: $e");
  // Silent error, tidak mengganggu flow absensi
}
```

## 📊 Benefits

1. **Better UX**: Voice guidance yang friendly
2. **Accessibility**: Membantu user yang kesulitan baca teks
3. **Engagement**: Suara ceria membuat pengalaman lebih menyenangkan
4. **Confirmation**: Audio feedback saat berhasil absen
5. **Personal Touch**: Menyebut nama user secara personal

## 🎯 Future Enhancements

Possible improvements:
1. ✨ "Silakan kedipkan mata 2 kali" saat face detected
2. ✨ "Wajah terdeteksi" saat face in frame
3. ✨ "Terlalu dekat" / "Terlalu jauh" untuk guidance
4. ✨ Customizable voice (pilih suara pria/wanita)
5. ✨ Volume control di settings
6. ✨ Enable/disable TTS toggle

## 📝 Notes

- TTS hanya aktif di **normal mode** (tidak saat locked)
- Welcome message **hanya sekali** per session
- Success message **setiap kali** berhasil submit
- TTS di-stop saat dispose untuk cleanup
- Error TTS tidak mengganggu flow attendance

Perfect untuk user experience! 🎤✨
