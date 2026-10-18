import '../data/attendance_models.dart';

/// Apa yang bisa dilakukan pegawai sekarang, dan kapan pintu absen berikutnya
/// terbuka. Server (`can_attend`) tetap penentu akhir; kelas ini hanya
/// menerjemahkannya ke keadaan layar + hitung mundur (logika v1 dipertahankan).
enum GateKind {
  /// Tidak ada jadwal hari ini.
  noSchedule,

  /// Jadwal hari ini libur/izin/cuti.
  off,

  /// Belum masuk jendela absen masuk.
  waitCheckIn,
  canCheckIn,

  /// Jendela absen masuk sudah lewat tanpa absen.
  missedCheckIn,

  /// Sudah masuk, menunggu jendela pulang.
  waitCheckOut,
  canCheckOut,

  /// Jendela pulang lewat dan belum absen pulang (akan tercatat lupa pulang).
  missedCheckOut,

  /// Masuk & pulang hari ini sudah tercatat.
  done,

  /// Flexi: jeda minimal sebelum boleh absen pulang.
  flexiCooldown,
}

class Gate {
  const Gate(this.kind, {this.until, this.message});

  final GateKind kind;

  /// Saat pintu berikutnya terbuka (untuk hitung mundur).
  final DateTime? until;
  final String? message;

  bool get canAttend =>
      kind == GateKind.canCheckIn || kind == GateKind.canCheckOut;

  static Gate resolve(
    AttendanceConfig cfg, {
    required bool checkedOutToday,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();

    if (cfg.isFlexi) {
      if (cfg.isCheckOut && !cfg.allowed && cfg.remainingSeconds > 0) {
        return Gate(
          GateKind.flexiCooldown,
          until: t.add(Duration(seconds: cfg.remainingSeconds)),
          message: cfg.reason,
        );
      }
      if (cfg.shift == null && !cfg.isCheckOut) {
        return Gate(GateKind.noSchedule, message: cfg.reason);
      }
      if (cfg.allowed) {
        return Gate(
          cfg.isCheckOut ? GateKind.canCheckOut : GateKind.canCheckIn,
        );
      }
      return Gate(GateKind.noSchedule, message: cfg.reason);
    }

    final shift = cfg.shift;
    if (shift == null) {
      return cfg.isCheckOut
          ? const Gate(GateKind.missedCheckOut)
          : Gate(GateKind.noSchedule, message: cfg.reason);
    }
    if (shift.isOff && !cfg.isCheckOut) {
      return Gate(GateKind.off, message: shift.name);
    }

    final day = cfg.scheduleDate ?? DateTime(t.year, t.month, t.day);
    final w = shift.windowsOn(day);

    if (cfg.isCheckOut) {
      if (cfg.allowed) return const Gate(GateKind.canCheckOut);
      if (t.isBefore(w.outStart)) {
        return Gate(
          GateKind.waitCheckOut,
          until: w.outStart,
          message: cfg.reason,
        );
      }
      return Gate(GateKind.missedCheckOut, message: cfg.reason);
    }

    // Arah absen masuk.
    if (cfg.hasAttendedToday || checkedOutToday) {
      return const Gate(GateKind.done);
    }
    if (cfg.allowed) return const Gate(GateKind.canCheckIn);
    if (t.isBefore(w.inStart)) {
      return Gate(GateKind.waitCheckIn, until: w.inStart, message: cfg.reason);
    }
    return Gate(GateKind.missedCheckIn, message: cfg.reason);
  }
}
