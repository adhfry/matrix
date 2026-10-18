/// Deteksi hidup berbasis kedipan (dipertahankan dari v1): wajah harus tegak
/// menghadap kamera lalu berkedip dua kali sebelum foto diambil.
enum LivenessStep { noFace, tilted, tooFar, blink, done }

class LivenessTracker {
  LivenessTracker({this.requiredBlinks = 2});

  final int requiredBlinks;
  int blinks = 0;
  bool _eyesClosed = false;
  LivenessStep step = LivenessStep.noFace;

  static const _maxAngle = 20.0;
  static const _closed = 0.3;
  static const _open = 0.6;

  /// Wajah harus mengisi minimal porsi ini dari lebar gambar.
  static const minFaceWidthRatio = 0.22;

  void reset() {
    blinks = 0;
    _eyesClosed = false;
    step = LivenessStep.noFace;
  }

  /// Panggil per bingkai kamera. `faceWidthRatio` = lebar wajah / lebar gambar.
  LivenessStep update({
    required bool hasFace,
    double? yaw,
    double? roll,
    double? leftEyeOpen,
    double? rightEyeOpen,
    double faceWidthRatio = 1,
  }) {
    if (step == LivenessStep.done) return step;
    if (!hasFace) {
      reset();
      return step;
    }
    if ((yaw?.abs() ?? 0) > _maxAngle || (roll?.abs() ?? 0) > _maxAngle) {
      reset();
      return step = LivenessStep.tilted;
    }
    if (faceWidthRatio < minFaceWidthRatio) {
      reset();
      return step = LivenessStep.tooFar;
    }
    if (leftEyeOpen != null && rightEyeOpen != null) {
      final closed = leftEyeOpen < _closed && rightEyeOpen < _closed;
      final open = leftEyeOpen > _open && rightEyeOpen > _open;
      if (closed && !_eyesClosed) {
        _eyesClosed = true;
      } else if (open && _eyesClosed) {
        _eyesClosed = false;
        blinks++;
      }
    }
    return step = blinks >= requiredBlinks
        ? LivenessStep.done
        : LivenessStep.blink;
  }
}
