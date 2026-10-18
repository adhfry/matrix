import 'package:intl/intl.dart';

/// Format angka, waktu, dan tanggal untuk tampilan (bahasa Indonesia).
abstract final class Fmt {
  static final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final _num = NumberFormat.decimalPattern('id_ID');

  static String rupiah(num v) => _rupiah.format(v);

  /// "~Rp 12,34" untuk tarif yang tidak bulat (aturan transparansi jaspel).
  static String approxRupiah(num v, {int decimals = 0}) =>
      '~${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: decimals).format(v)}';

  static String number(num v) => _num.format(v);

  /// 9000 -> "2 j 30 m". Detik ditampilkan bila kurang dari satu menit.
  static String hm(int seconds) {
    final s = seconds.abs();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h == 0 && m == 0) return s == 0 ? '0 m' : '$s d';
    if (h == 0) return '$m m';
    return m == 0 ? '$h j' : '$h j $m m';
  }

  /// Versi panjang untuk label & pembaca layar: "2 jam 30 menit".
  static String hmLong(int seconds) {
    final s = seconds.abs();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final d = s % 60;
    final parts = <String>[
      if (h > 0) '$h jam',
      if (m > 0) '$m menit',
      if (h == 0 && d > 0) '$d detik',
    ];
    return parts.isEmpty ? '0 menit' : parts.join(' ');
  }

  /// Timer berjalan: "07:42:09".
  static String clock(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
  }

  /// "07:30:00" -> "07.30" (gaya jam Indonesia).
  static String time(String? hhmmss) {
    if (hhmmss == null || hhmmss.length < 5) return '–';
    return hhmmss.substring(0, 5).replaceAll(':', '.');
  }

  static String timeOf(DateTime d) => DateFormat('HH.mm', 'id_ID').format(d);

  static String dayLong(DateTime d) =>
      DateFormat('EEEE, d MMMM y', 'id_ID').format(d);
  static String dayMedium(DateTime d) =>
      DateFormat('EEE, d MMM', 'id_ID').format(d);
  static String dayShort(DateTime d) => DateFormat('EEE', 'id_ID').format(d);
  static String monthYear(DateTime d) =>
      DateFormat('MMMM y', 'id_ID').format(d);
  static String monthShort(DateTime d) => DateFormat('MMM', 'id_ID').format(d);
  static String date(DateTime d) => DateFormat('d MMM y', 'id_ID').format(d);

  /// "08-2026" -> DateTime(2026, 8).
  static DateTime? period(String? mmYyyy) {
    if (mmYyyy == null) return null;
    final p = mmYyyy.split('-');
    if (p.length != 2) return null;
    final m = int.tryParse(p[0]);
    final y = int.tryParse(p[1]);
    return m == null || y == null ? null : DateTime(y, m);
  }

  /// Sapaan menurut jam lokal.
  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }
}

/// Parsing longgar untuk nilai JSON dari Laravel (angka bisa datang sebagai string).
abstract final class J {
  static int i(Object? v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return num.tryParse(v)?.round() ?? fallback;
    return fallback;
  }

  static double d(Object? v, [double fallback = 0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static bool b(Object? v) => v == true || v == 1 || v == '1' || v == 'true';

  static String? s(Object? v) {
    if (v == null) return null;
    final t = '$v';
    return t.isEmpty ? null : t;
  }

  static Map<String, dynamic> m(Object? v) =>
      v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

  static List<Map<String, dynamic>> l(Object? v) => v is List
      ? v
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => e.cast<String, dynamic>())
            .toList()
      : const [];

  static DateTime? dt(Object? v) =>
      v is String ? DateTime.tryParse(v.replaceFirst(' ', 'T')) : null;

  /// Tanggal saja. Menerima "2026-10-18" atau ISO UTC "2026-10-17T17:00:00Z"
  /// (Carbon tanpa format) yang dikonversi ke waktu lokal dulu supaya tidak
  /// bergeser sehari.
  static DateTime? date(Object? v) {
    final d = dt(v);
    if (d == null) return null;
    final l = d.isUtc ? d.toLocal() : d;
    return DateTime(l.year, l.month, l.day);
  }
}
