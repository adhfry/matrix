import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Detik berjalan untuk timer jam kerja & penanda "sekarang" pada pita shift.
/// Hanya widget kecil yang menontonnya, jadi layar tidak dibangun ulang penuh.
final clockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});
