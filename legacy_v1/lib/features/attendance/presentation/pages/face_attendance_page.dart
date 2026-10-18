import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/models/attendance_location_model.dart';
import '../../data/models/attendance_config_model.dart';

class FaceAttendancePage extends ConsumerStatefulWidget {
  final AttendanceConfigModel config;

  const FaceAttendancePage({super.key, required this.config});

  @override
  ConsumerState<FaceAttendancePage> createState() => _FaceAttendancePageState();
}

class _FaceAttendancePageState extends ConsumerState<FaceAttendancePage>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  bool _isFaceDetected = false;
  int _blinkCount = 0;
  bool _wasEyesClosed = false;
  String _statusMessage = 'Posisikan wajah Anda di dalam oval';
  bool _isProcessing = false;

  // Location
  bool _mapReady = false;
  Position? _currentPosition;
  bool _isFirstLoading = true;
  final MapController _mapController = MapController();
  List<AttendanceLocationModel> _allowedLocations = [];
  AttendanceLocationModel? _selectedLocation;
  final List<Marker> _markers = [];
  final List<CircleMarker> _circles = [];

  // Stream Location
  StreamSubscription<Position>? _positionStreamSubscription;

  // Locked / Fixed Mode Logic
  bool _isLockedMode = false;
  Timer? _countdownTimer;
  Duration _remainingDuration = Duration.zero; // For locked countdown
  int _flexiRemainingSeconds = 0; // For flexi checkout countdown
  bool _canProceed = true;
  String _lockedTitle = "Belum Waktunya"; // Judul dinamis untuk lock screen

  // Face detection
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  // Text-to-Speech
  final FlutterTts _flutterTts = FlutterTts();
  bool _hasSpokeWelcome = false;
  bool _hasSpokeBlink = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTts();

    // --- LOGIKA PENENTUAN MODE (CAMERA vs LOCKED) ---
    final bool isFixed = widget.config.user.attendanceMode == 'Fixed';
    final bool canAttend = widget.config.canAttend.allowed;
    final bool hasAttended = widget.config.hasAttendedToday;
    final String nextAction = widget.config.nextAction;

    // Logika Gembok (Locked Mode):
    // User Fixed harus mengikuti window attendance yang ketat
    bool shouldLock = false;

    if (isFixed) {
      // KASUS 1: API bilang tidak boleh absen (di luar window)
      if (!canAttend) {
        shouldLock = true;
      }
      // KASUS 2: Sudah check-in hari ini tapi next action CHECK_IN lagi (sudah selesai, tunggu besok)
      else if (hasAttended && nextAction == 'CHECK_IN') {
        shouldLock = true;
      }
    }

    if (shouldLock) {
      // MODE TERKUNCI
      _isLockedMode = true;
      _startLockedCountdown();
      _initialSetup(skipCamera: true);
    } else {
      // MODE NORMAL
      _isLockedMode = false;
      _checkFlexiCountdown();
      _initialSetup(skipCamera: false);
    }
  }

  void _checkFlexiCountdown() {
    final config = widget.config;

    // Get remaining seconds from backend (biasanya untuk delay checkout)
    _flexiRemainingSeconds = config.canAttend.remainingSeconds;
    _canProceed = config.canAttend.allowed;

    if (!_canProceed && _flexiRemainingSeconds > 0) {
      _startFlexiCountdown();
    }
  }

  void _startFlexiCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_flexiRemainingSeconds > 0) {
          _flexiRemainingSeconds--;
        }

        if (_flexiRemainingSeconds == 0) {
          _canProceed = true;
          timer.cancel();
        }
      });
    });
  }

  // ========== TTS FUNCTIONS ==========
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
    // Tunggu sampai TTS selesai berbicara (tambahan delay untuk memastikan)
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  Future<void> _speakBlink() async {
    if (_hasSpokeBlink) return;
    
    _hasSpokeBlink = true;
    await _speak("Kedipkan mata Anda");
  }

  // --- LOGIKA COUNTDOWN DINAMIS UNTUK MODE FIXED (LOCKED) ---
  void _startLockedCountdown() {
    // 1. Hitung durasi awal saat init
    _calculateTargetTime();

    // 2. Update setiap detik
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingDuration.inSeconds > 0) {
          _remainingDuration -= const Duration(seconds: 1);
        } else {
          // Waktu habis!
          _remainingDuration = Duration.zero;
          timer.cancel();

          // Cek apakah ini kasus "lupa checkout" atau memang waktunya check-in
          final nextAction = widget.config.nextAction;
          final canAttend = widget.config.canAttend.allowed;

          // Jika next action CHECK_OUT dan tidak allowed = LUPA CHECKOUT
          // Jangan unlock kamera!
          if (nextAction == 'CHECK_OUT' && !canAttend) {
            print("⚠️ Countdown habis tapi lupa checkout - tetap locked");
            return;
          }

          // Auto-unlock dan buka kamera (untuk kasus normal)
          _unlockAndOpenCamera();
        }
      });
    });
  }

  // Function untuk unlock dan buka kamera otomatis
  Future<void> _unlockAndOpenCamera() async {
    print("🔓 Unlocking and opening camera...");

    // Cancel timer
    _countdownTimer?.cancel();

    setState(() {
      _isLockedMode = false;
      _canProceed = true;
      _statusMessage = "Mempersiapkan kamera...";
    });

    // Request camera permission if not granted
    final cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        if (mounted) {
          setState(() {
            _statusMessage = "Izin kamera diperlukan untuk absensi";
          });
        }
        return;
      }
    }

    // Initialize camera
    if (mounted) {
      setState(() {
        _statusMessage = "Posisikan wajah Anda di dalam oval";
      });
      await _initializeCamera();
    }
  }

  void _calculateTargetTime() {
    final schedule = widget.config.todaySchedule;
    final nextAction = widget.config.nextAction; // "CHECK_IN" atau "CHECK_OUT"
    final hasAttended = widget.config.hasAttendedToday;
    final canAttend = widget.config.canAttend.allowed;

    // Default values
    _remainingDuration = Duration.zero;
    _lockedTitle = "Jadwal Tidak Tersedia";

    if (schedule == null) return;

    try {
      final now = DateTime.now();
      DateTime targetTime;

      // --- KASUS 1: MENUNGGU CHECK IN ---
      if (nextAction == 'CHECK_IN') {
        final timeStr = schedule.shift.checkInStartTime; // "15:20:00"
        targetTime = _parseTimeOnDate(now, timeStr);

        // FIX: Jika belum absen DAN waktu target masih di depan = menunggu check in hari ini
        if (!hasAttended && !targetTime.isBefore(now)) {
          // Normal: Menunggu jam check in hari ini
          _lockedTitle = "Menunggu Jam Masuk";
          _statusMessage = "Belum waktunya Check-In";
        }
        // Jika belum absen TAPI waktu check in sudah lewat
        else if (!hasAttended && targetTime.isBefore(now)) {
          // Cek apakah masih dalam window check in
          final checkInEnd = _parseTimeOnDate(
            now,
            schedule.shift.checkInEndTime,
          );

          if (now.isBefore(checkInEnd)) {
            // Masih dalam window check in, harusnya sudah bisa absen
            _remainingDuration = Duration.zero;
            _lockedTitle = "Bisa Check-In Sekarang";
            _statusMessage = "Silakan Check-In";
            return;
          } else {
            // Sudah lewat window check in hari ini, tunggu besok
            targetTime = targetTime.add(const Duration(days: 1));
            _lockedTitle = "Check-In Besok";
            _statusMessage = "Window Check-In Hari Ini Sudah Lewat";
          }
        }
        // Sudah absen hari ini
        else if (hasAttended) {
          // Sudah absen hari ini, countdown ke Check In Besok
          targetTime = targetTime.add(const Duration(days: 1));
          _lockedTitle = "Check-In Besok";
          _statusMessage = "Sampai Jumpa Besok!";
        }
      }
      // --- KASUS 2: MENUNGGU CHECK OUT ---
      else {
        // nextAction == 'CHECK_OUT'
        final timeStr = schedule.shift.checkOutStartTime; // "15:40:00"
        targetTime = _parseTimeOnDate(now, timeStr);

        // Handle Shift Lintas Hari (Cross Midnight)
        if (schedule.shift.crossesMidnight) {
          if (targetTime.isBefore(now)) {
            targetTime = targetTime.add(const Duration(days: 1));
          }
          _lockedTitle = "Menunggu Jam Pulang";
          _statusMessage = "Belum waktunya Check-Out";
        } else {
          // Shift Normal
          if (targetTime.isBefore(now)) {
            // Cek apakah masih dalam window checkout
            final checkOutEnd = _parseTimeOnDate(
              now,
              schedule.shift.checkOutEndTime,
            );

            if (now.isBefore(checkOutEnd)) {
              // Masih dalam window checkout
              _remainingDuration = Duration.zero;
              _lockedTitle = "Bisa Check-Out Sekarang";
              _statusMessage = "Silakan Check-Out";
              return;
            } else {
              // Sudah lewat window checkout - LUPA CHECKOUT
              targetTime = _parseTimeOnDate(
                now.add(const Duration(days: 1)),
                schedule.shift.checkInStartTime,
              );
              targetTime = targetTime.add(const Duration(days: 1));
              _lockedTitle = "Terlewat Check-Out";
              _statusMessage =
                  "Anda lupa check-out. Akan dikenakan penalty. Check-in kembali besok.";
              return;
            }
          } else {
            // Belum sampai waktu checkout start
            _lockedTitle = "Menunggu Jam Pulang";
            _statusMessage = "Belum waktunya Check-Out";
          }
        }
      }

      final diff = targetTime.difference(now);
      _remainingDuration = diff.isNegative ? Duration.zero : diff;
    } catch (e) {
      print("Error calculating time: $e");
      _remainingDuration = Duration.zero;
    }
  }

  // Helper untuk menggabungkan Jam dari string (H:m:s) dengan Tanggal hari ini
  DateTime _parseTimeOnDate(DateTime date, String timeStr) {
    try {
      final parts = timeStr.split(':');
      return DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
        parts.length > 2 ? int.parse(parts[2]) : 0,
      );
    } catch (e) {
      return date;
    }
  }

  Future<void> _initialSetup({required bool skipCamera}) async {
    await _requestPermissions(skipCamera: skipCamera);
    _loadLocations();
    _startLocationStream();

    if (!skipCamera) {
      _initializeCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (_positionStreamSubscription == null ||
          _positionStreamSubscription!.isPaused) {
        _startLocationStream();
      }
      // Re-calculate target time on resume agar timer sinkron
      if (_isLockedMode) {
        _calculateTargetTime();
      }
    } else if (state == AppLifecycleState.paused) {
      _positionStreamSubscription?.pause();
    }
  }

  Future<void> _requestPermissions({required bool skipCamera}) async {
    final permissions = <Permission>[
      Permission.location,
      if (!skipCamera) Permission.camera,
      Permission.notification,
    ];

    final statuses = await permissions.request();

    final allGranted = statuses.values.every((status) => status.isGranted);
    if (!allGranted && mounted) {
      SnackBarHelper.showError(
        context,
        'Beberapa permission diperlukan untuk fitur ini',
      );
    }
  }

  Future<void> _loadLocations() async {
    try {
      final repository = ref.read(attendanceRepositoryProvider);
      final locations = await repository.getAllowedLocations();

      if (mounted) {
        setState(() {
          _allowedLocations = locations;
          _updateMarkersAndCircles();
          if (_currentPosition != null) {
            _calculateDistances(_currentPosition!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        // Silent error or snackbar
      }
    }
  }

  void _updateMarkersAndCircles() {
    _markers.clear();
    _circles.clear();

    if (_currentPosition != null) {
      _markers.add(_buildUserMarker(_currentPosition!));
    }

    for (var location in _allowedLocations) {
      final latLng = LatLng(location.latitude, location.longitude);

      _markers.add(
        Marker(
          point: latLng,
          width: 75,
          height: 75,
          child: Column(
            children: [
              Icon(Icons.location_on, color: AppColors.error, size: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                ),
                child: Text(
                  location.name,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );

      _circles.add(
        CircleMarker(
          point: latLng,
          radius: location.radiusMeters.toDouble(),
          useRadiusInMeter: true,
          color: AppColors.primary.withOpacity(0.1),
          borderColor: AppColors.primary,
          borderStrokeWidth: 2,
        ),
      );
    }
  }

  Marker _buildUserMarker(Position position) {
    return Marker(
      point: LatLng(position.latitude, position.longitude),
      width: 30,
      height: 30,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }

  Future<void> _initializeCamera() async {
    if (_isLockedMode) return; // Double check

    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      try {
        await _cameraController!.setZoomLevel(0.5);
      } catch (_) {}

      if (mounted) {
        setState(() => _isCameraInitialized = true);
        await _cameraController!.startImageStream(_processCameraImage);
        
        // Speak welcome message setelah kamera ready
        _speakWelcome();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Gagal inisialisasi kamera');
      }
    }
  }

  // --- LOGIKA LOCATION STREAMING ---
  Future<void> _startLocationStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted)
        SnackBarHelper.showError(context, 'Layanan lokasi tidak aktif');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) => _handlePositionUpdate(position),
          onError: (e) {
            if (mounted) {
              setState(() => _isFirstLoading = false);
            }
          },
        );
  }

  void _handlePositionUpdate(Position position) {
    if (!mounted) return;

    setState(() {
      _currentPosition = position;
      _isFirstLoading = false;
      _updateMarkersAndCircles();
      _calculateDistances(position);
    });

    if (_mapReady) {
      _centerMapOnUser(position);
    }
  }

  void _centerMapOnUser(Position position) {
    const double latOffset =
        0.0004; // Offset agar marker user ada di bawah oval
    _mapController.move(
      LatLng(position.latitude + latOffset, position.longitude),
      19,
    );
  }

  void _calculateDistances(Position currentPos) {
    if (_allowedLocations.isEmpty) return;

    for (var i = 0; i < _allowedLocations.length; i++) {
      final location = _allowedLocations[i];
      final distance = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        location.latitude,
        location.longitude,
      );

      _allowedLocations[i] = location.copyWith(
        distance: distance,
        isInRange: distance <= location.radiusMeters,
      );
    }

    _allowedLocations.sort(
      (a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0),
    );

    setState(() {
      if (_selectedLocation == null) {
        _selectedLocation = _allowedLocations.first;
      } else {
        try {
          _selectedLocation = _allowedLocations.firstWhere(
            (loc) => loc.id == _selectedLocation!.id,
          );
        } catch (_) {
          _selectedLocation = _allowedLocations.first;
        }
      }
    });
  }

  void _processCameraImage(CameraImage image) async {
    if (_isLockedMode) return;
    if (_isDetecting || _isProcessing) return;
    if (!_canProceed) return;

    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        if (faces.isEmpty) {
          setState(() {
            _isFaceDetected = false;
            _statusMessage = 'Wajah tidak terdeteksi';
            _blinkCount = 0;
            _wasEyesClosed = false;
            _hasSpokeBlink = false; // Reset untuk speak lagi ketika wajah terdeteksi
          });
        } else {
          final face = faces.first;
          // Validasi Orientasi
          if (face.headEulerAngleY != null && face.headEulerAngleZ != null) {
            if (face.headEulerAngleY!.abs() > 20 ||
                face.headEulerAngleZ!.abs() > 20) {
              setState(() {
                _isFaceDetected = false;
                _statusMessage = 'Posisikan wajah tegak menghadap kamera';
                _blinkCount = 0;
                _wasEyesClosed = false;
                _hasSpokeBlink = false; // Reset untuk speak lagi
              });
              _isDetecting = false;
              return;
            }
          }

          _isFaceDetected = true;
          String newMessage = 'Wajah terdeteksi - Kedipkan mata';
          if (_blinkCount > 0) newMessage += ' (${_blinkCount}/2)';

          // Speak "Kedipkan mata Anda" saat wajah pertama kali terdeteksi
          if (!_hasSpokeBlink) {
            _speakBlink();
          }

          if (face.leftEyeOpenProbability != null &&
              face.rightEyeOpenProbability != null) {
            final leftEye = face.leftEyeOpenProbability!;
            final rightEye = face.rightEyeOpenProbability!;
            final bothEyesClosed = leftEye < 0.3 && rightEye < 0.3;
            final bothEyesOpen = leftEye > 0.6 && rightEye > 0.6;

            if (bothEyesClosed && !_wasEyesClosed) {
              _wasEyesClosed = true;
            } else if (bothEyesOpen && _wasEyesClosed) {
              _blinkCount++;
              _wasEyesClosed = false;
              newMessage =
                  'Wajah terdeteksi - Kedipkan mata (${_blinkCount}/2)';
            }
          }

          if (_blinkCount >= 2) {
            setState(() => _statusMessage = 'Mengambil foto...');
            await _captureAndSubmit();
          } else {
            setState(() => _statusMessage = newMessage);
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
    _isDetecting = false;
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();
      final inputImageData = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation270deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      );
      return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
    } catch (e) {
      return null;
    }
  }

  Future<void> _captureAndSubmit() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    if (!_canProceed) {
      SnackBarHelper.showError(
        context,
        'Mohon tunggu hingga countdown selesai',
      );
      setState(() => _blinkCount = 0);
      return;
    }
    if (_currentPosition == null) {
      setState(() => _statusMessage = 'Menunggu lokasi...');
      if (_positionStreamSubscription == null) _startLocationStream();
      return;
    }
    if (_selectedLocation == null) {
      SnackBarHelper.showError(context, 'Pilih lokasi absensi');
      setState(() => _blinkCount = 0);
      return;
    }

    final bool isLocationFree = widget.config.user.isLocationFree;
    final bool isFlexi = widget.config.user.isFlexi; // Sesuaikan model

    if (!isLocationFree && !isFlexi) {
      if (_selectedLocation!.isInRange == false) {
        SnackBarHelper.showError(
          context,
          'Anda di luar jangkauan lokasi absensi',
        );
        setState(() => _blinkCount = 0);
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      await _cameraController!.stopImageStream();
      final XFile photoXFile = await _cameraController!.takePicture();
      final File photoFile = File(photoXFile.path);
      final repository = ref.read(attendanceRepositoryProvider);
      final bool isCheckOut = widget.config.nextAction == 'CHECK_OUT';

      await (isCheckOut
          ? repository.checkOut(
              latitude: _currentPosition!.latitude,
              longitude: _currentPosition!.longitude,
              locationId: _selectedLocation!.id,
              photo: photoFile,
            )
          : repository.checkIn(
              latitude: _currentPosition!.latitude,
              longitude: _currentPosition!.longitude,
              locationId: _selectedLocation!.id,
              photo: photoFile,
            ));

      if (mounted) {
        // Speak success before navigating
        await _speakSuccess();
        
        Navigator.pop(context, true);
        SnackBarHelper.showSuccess(
          context,
          isCheckOut ? 'Check-out berhasil!' : 'Check-in berhasil!',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Gagal: ${e.toString()}';
          _isProcessing = false;
          _blinkCount = 0;
          _wasEyesClosed = false;
        });
        try {
          await _cameraController?.startImageStream(_processCameraImage);
        } catch (_) {}
        SnackBarHelper.showError(context, e.toString());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _faceDetector.close();
    _flutterTts.stop();
    _mapController.dispose();
    _positionStreamSubscription?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // --- UI SECTION ---

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double cameraSize = math.min(size.width - 40, 480);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // Background Map
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(-6.2088, 106.8456),
                  initialZoom: 18.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    setState(() => _mapReady = true);
                    if (_currentPosition != null) {
                      _centerMapOnUser(_currentPosition!);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.silakes.matrix',
                  ),
                  CircleLayer(circles: _circles),
                  MarkerLayer(markers: _markers),
                ],
              ),
            ),

            if (_isFirstLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black12,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),

            // Dimmed Overlay
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),

            // Camera Oval / Locked View
            Positioned(
              top: 100,
              left: (size.width - cameraSize) / 2,
              child: _buildCircularContainer(cameraSize),
            ),

            // Top Bar
            Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),

            // Status Message
            Positioned(
              top: 100 + cameraSize + 20,
              left: 0,
              right: 0,
              child: _buildStatusMessage(),
            ),

            // Bottom Sheet Location
            DraggableScrollableSheet(
              initialChildSize: 0.25,
              minChildSize: 0.15,
              maxChildSize: 0.6,
              builder: (context, scrollController) {
                return _buildLocationSelector(scrollController);
              },
            ),

            if (_isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Widget Pembungkus Oval (bisa isinya Kamera atau Lock Screen)
  Widget _buildCircularContainer(double size) {
    // Tentukan warna border
    Color borderColor;
    if (_isLockedMode) {
      borderColor = Colors.grey;
    } else {
      borderColor = _isFaceDetected ? AppColors.success : AppColors.warning;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(
        // Switch content based on mode
        child: _isLockedMode ? _buildLockedPreview() : _buildCameraContent(),
      ),
    );
  }

  // Konten Kamera Normal
  Widget _buildCameraContent() {
    if (_isCameraInitialized && _cameraController!.value.isInitialized) {
      final size = _cameraController!.value.previewSize;
      if (size == null) return Container(color: Colors.black);
      return LayoutBuilder(
        builder: (context, constraints) {
          return ClipRect(
            child: OverflowBox(
              maxHeight: double.infinity,
              maxWidth: double.infinity,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: size.height,
                  height: size.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          );
        },
      );
    } else {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
  }

  // Tampilan Gembok & Countdown
  Widget _buildLockedPreview() {
    final hours = _remainingDuration.inHours.toString().padLeft(2, '0');
    final minutes = (_remainingDuration.inMinutes % 60).toString().padLeft(
      2,
      '0',
    );
    final seconds = (_remainingDuration.inSeconds % 60).toString().padLeft(
      2,
      '0',
    );

    return Container(
      color: const Color(0xFF2C2C2C), // Dark grey background
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Gembok Besar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outlined,
              color: Colors.white70,
              size: 50,
            ),
          ),
          const SizedBox(height: 20),

          // Judul Status (Check In / Check Out)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _lockedTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Countdown Timer
          Text(
            "$hours : $minutes : $seconds",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),

          const SizedBox(height: 8),
          Text(
            "Menuju Waktu Absen",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          // Hide face status badge if locked
          if (!_isLockedMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isFaceDetected
                    ? AppColors.success.withOpacity(0.9)
                    : AppColors.warning.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isFaceDetected ? Icons.face : Icons.face_retouching_off,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isFaceDetected ? 'Wajah Terdeteksi' : 'Cari Wajah...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage() {
    // Jika Locked Mode
    if (_isLockedMode) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_clock, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _statusMessage, // "Belum waktunya Check-In/Out"
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // Jika Flexi Countdown
    if (!_canProceed && !_isLockedMode && _flexiRemainingSeconds > 0) {
      final minutes = _flexiRemainingSeconds ~/ 60;
      final seconds = _flexiRemainingSeconds % 60;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.timer, color: AppColors.warning),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tunggu untuk Check-Out',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }

    // Normal Status
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _isFaceDetected ? Icons.check_circle : Icons.info_outline,
            color: _isFaceDetected ? AppColors.success : AppColors.info,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSelector(ScrollController scrollController) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Lokasi Absensi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (widget.config.user.isLocationFree)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.info,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'WFA Mode',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_allowedLocations.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("Memuat lokasi..."),
                    ),
                  )
                else
                  ..._allowedLocations.map((location) {
                    final isNearest = _selectedLocation?.id == location.id;
                    final distance = location.distance ?? 0;
                    final distanceText = distance < 1000
                        ? '${distance.toStringAsFixed(0)} m'
                        : '${(distance / 1000).toStringAsFixed(1)} km';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: isNearest ? 4 : 1,
                      color: isNearest
                          ? AppColors.primary.withOpacity(0.1)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isNearest
                            ? BorderSide(color: AppColors.primary, width: 2)
                            : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: Icon(
                          location.isInRange == true
                              ? Icons.check_circle
                              : Icons.location_on,
                          color: location.isInRange == true
                              ? AppColors.success
                              : AppColors.textSecondary,
                          size: 28,
                        ),
                        title: Text(
                          location.name,
                          style: TextStyle(
                            fontWeight: isNearest
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '$distanceText dari Anda',
                          style: TextStyle(
                            color: isNearest
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                        trailing: Icon(
                          isNearest
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isNearest
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        onTap: () {
                          setState(() {
                            _selectedLocation = location;
                          });
                        },
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
