import 'dart:math' as math;

import '../data/scanner_repository.dart';
import 'ktp_image.dart';
import 'ktp_reference.dart';

/// Satu baris teks hasil OCR beserta kotaknya (piksel gambar) dan
/// keyakinan pengenal (0-1; 1 bila tidak tersedia).
class OcrLine {
  const OcrLine(
    this.text,
    this.left,
    this.top,
    this.right,
    this.bottom, {
    this.confidence = 1,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double confidence;

  double get cy => (top + bottom) / 2;
  double get height => bottom - top;
}

/// Hasil urai KTP di perangkat.
class KtpParse {
  const KtpParse({
    required this.fields,
    required this.checks,
    required this.confident,
    this.nikDigits = '',
    this.province,
    this.unsure = const {},
  });

  final KtpFields fields;

  /// Digit yang terbaca di baris NIK (untuk pesan "terbaca N digit").
  final String nikDigits;

  /// Kepala kartu ("JAWA TIMUR"), untuk cek 2 digit awal NIK.
  final String? province;

  /// Kolom yang barisnya dibaca ML Kit dengan keyakinan rendah.
  final Set<String> unsure;
  final List<KtpCheck> checks;

  /// NIK valid & cocok dengan provinsi/tanggal lahir/jenis kelamin di kartu,
  /// NIK & nama terbaca jelas, paling banyak 2 kolom kosong & 2 kolom ragu.
  /// Bila false,
  /// layar review meminta bantuan AI server.
  final bool confident;
}

enum _L {
  nik,
  nama,
  ttl,
  jk,
  alamat,
  rtrw,
  keldesa,
  kecamatan,
  agama,
  status,
  pekerjaan,
  wn,
  berlaku,
  provinsi,
  kabupaten,
}

/// Label KTP tanpa spasi/tanda baca.
const _labels = <_L, List<String>>{
  _L.nik: ['NIK'],
  _L.nama: ['NAMA'],
  _L.ttl: ['TEMPATTGLLAHIR', 'TEMPATTANGGALLAHIR', 'TEMPATLAHIR', 'TGLLAHIR'],
  _L.jk: ['JENISKELAMIN'],
  _L.alamat: ['ALAMAT'],
  _L.rtrw: ['RTRW'],
  _L.keldesa: ['KELURAHANDESA', 'KELDESA'],
  _L.kecamatan: ['KECAMATAN'],
  _L.agama: ['AGAMA'],
  _L.status: ['STATUSPERKAWINAN'],
  _L.pekerjaan: ['PEKERJAAN'],
  _L.wn: ['KEWARGANEGARAAN'],
  _L.berlaku: ['BERLAKUHINGGA'],
  _L.provinsi: ['PROVINSI'],
  _L.kabupaten: ['KABUPATEN', 'KOTA'],
};

const _fieldOf = <_L, String>{
  _L.nik: 'nik',
  _L.nama: 'name',
  _L.ttl: 'tempat_lahir',
  _L.jk: 'gender',
  _L.alamat: 'alamat',
  _L.rtrw: 'rt_rw',
  _L.keldesa: 'kel_desa',
  _L.kecamatan: 'kecamatan',
  _L.agama: 'agama',
  _L.status: 'status_perkawinan',
  _L.pekerjaan: 'pekerjaan',
};

const _required = {
  'nik': 'NIK',
  'name': 'Nama',
  'tempat_lahir': 'Tempat lahir',
  'tgl_lahir': 'Tanggal lahir',
  'gender': 'Jenis kelamin',
  'alamat': 'Alamat',
  'rt_rw': 'RT/RW',
  'kel_desa': 'Kel/Desa',
  'kecamatan': 'Kecamatan',
  'agama': 'Agama',
  'status_perkawinan': 'Status perkawinan',
  'pekerjaan': 'Pekerjaan',
};

/// Baris dengan keyakinan ML Kit di bawah ini dianggap kurang jelas.
const unsureBelow = 0.5;

/// Urai baris OCR KTP menjadi kolom pasien. Baris dikelompokkan per tinggi
/// (label & nilai sering terbaca sebagai blok terpisah), label dicocokkan
/// longgar terhadap salah baca OCR, nilai dibetulkan dengan data acuan KTP,
/// lalu NIK dicek silang dengan isi kartu.
KtpParse parseKtp(List<OcrLine> lines, {DateTime? now}) {
  final rows = _groupRows(lines);
  final width = lines.isEmpty
      ? 1.0
      : lines.map((l) => l.right).reduce(math.max);
  final raw = <_L, String>{};
  final conf = <_L, double>{};
  final f = <String, String?>{for (final k in KtpFields.keys) k: null};

  _L? last;
  double lastLeft = 0;
  var continued = 0;
  for (final row in rows) {
    final text = row.text;
    final hit = _matchLabel(text);
    if (hit != null) {
      final (label, value) = hit;
      if (!raw.containsKey(label)) {
        raw[label] = value;
        conf[label] = row.confidence;
      }
      last = label;
      lastLeft = row.left;
      continued = 0;
      continue;
    }
    // Nama & alamat panjang terlipat ke baris berikut tanpa label, mulai dari
    // kolom nilai (lebih kanan dari kolom label).
    if ((last == _L.nama || last == _L.alamat) &&
        continued == 0 &&
        row.left > lastLeft + width * 0.12 &&
        RegExp(r'[A-Z]{2}').hasMatch(text)) {
      raw[last!] = '${raw[last] ?? ''} $text'.trim();
      conf[last] = math.min(conf[last] ?? 1, row.confidence);
      continued++;
      continue;
    }
    // Baris berisi NIK tanpa label terbaca.
    if (!raw.containsKey(_L.nik)) {
      final d = _digits(text);
      if (d.length >= 16 && !RegExp(r'[A-Z]{3,}').hasMatch(text)) {
        raw[_L.nik] = text;
        conf[_L.nik] = row.confidence;
      }
    }
  }

  // NIK: perbaiki huruf yang mirip angka, ambil 16 digit pertama.
  final nikDigits = _digits(raw[_L.nik] ?? '');
  if (nikDigits.length >= 16) f['nik'] = nikDigits.substring(0, 16);

  f['name'] = _clean(raw[_L.nama], r"[^A-Z .,'\-]");

  // Kepala kartu: "PROVINSI JAWA TIMUR", "KABUPATEN SUMENEP" / "KOTA ...".
  final province = _clean(raw[_L.provinsi], r'[^A-Z ]');
  final regency = _clean(raw[_L.kabupaten], r'[^A-Z ]');

  if (raw[_L.ttl] case final v?) {
    final (place, date) = _splitPlaceDate(v, now ?? DateTime.now());
    var p = _clean(place, r"[^A-Z .\-]");
    // Tempat lahir sering sama dengan kabupaten di kepala kartu; bila mirip
    // (beda 1-2 huruf), pakai ejaan kepala kartu yang lebih besar & jelas.
    if (p != null && regency != null && p != regency) {
      final a = p.replaceAll(' ', '');
      final b = regency.replaceAll(' ', '');
      if (_distance(a, b) <= math.max(1, b.length ~/ 4)) p = regency;
    }
    f['tempat_lahir'] = p;
    f['tgl_lahir'] = date;
  }

  final jk = raw[_L.jk] ?? '';
  if (jk.contains('LAKI')) {
    f['gender'] = 'L';
  } else if (jk.contains('PEREMP') || jk.contains('WANITA')) {
    f['gender'] = 'P';
  }
  final goldar = RegExp(
    r'DARAH\W*(AB|A|B|O|0)(?![A-Z])',
  ).firstMatch(jk)?.group(1);
  if (goldar != null) f['golongan_darah'] = goldar == '0' ? 'O' : goldar;

  f['alamat'] = _address(_clean(raw[_L.alamat], r"[^A-Z0-9 .,/\-]"));
  f['rt_rw'] = _rtRw(raw[_L.rtrw]);
  f['kel_desa'] = _dropStray(_clean(raw[_L.keldesa], r"[^A-Z0-9 .\-]"));
  f['kecamatan'] = _dropStray(_clean(raw[_L.kecamatan], r"[^A-Z .\-]"));
  f['agama'] = _agama(raw[_L.agama]);
  f['status_perkawinan'] = _status(raw[_L.status]);
  f['pekerjaan'] = _occupation(_clean(raw[_L.pekerjaan], r"[^A-Z /.\-]"));

  final unsure = {
    for (final e in conf.entries)
      if (e.value < unsureBelow && _fieldOf[e.key] != null) _fieldOf[e.key]!,
  };
  return finalizeKtp(
    f,
    nikDigits: nikDigits,
    province: province,
    unsure: unsure,
  );
}

/// Mutu hasil untuk memilih varian terbaik: yakin > NIK valid > kolom terisi
/// > sedikit kolom ragu.
int ktpScore(KtpParse p) =>
    (p.confident ? 100 : 0) +
    (p.checks.any((c) => c.field == 'nik' && c.isError) ? 0 : 20) +
    p.fields.values.values.where((v) => v != null).length * 2 -
    p.unsure.length;

/// Gabungkan hasil beberapa varian gambar: varian terbaik jadi dasar, kolom
/// kosongnya diisi dari varian lain, lalu cek silang dihitung ulang.
KtpParse mergeKtp(List<KtpParse> parses) {
  if (parses.length == 1) return parses.single;
  final ranked = [...parses]..sort((a, b) => ktpScore(b) - ktpScore(a));
  // Kolom yang hanya "diambil dari NIK" bukan bacaan asli; jangan dipakai
  // menutup bacaan varian lain.
  Map<String, String?> own(KtpParse p) => {
    for (final e in p.fields.values.entries)
      e.key:
          p.checks.any(
            (c) => c.field == e.key && c.message.startsWith('Diambil'),
          )
          ? null
          : e.value,
  };
  final f = own(ranked.first);
  final unsure = {...ranked.first.unsure};
  for (final p in ranked.skip(1)) {
    for (final e in own(p).entries) {
      if (f[e.key] == null && e.value != null) {
        f[e.key] = e.value;
        if (p.unsure.contains(e.key)) unsure.add(e.key);
      }
    }
  }
  final digits = ranked
      .map((p) => p.nikDigits)
      .reduce((a, b) => a.length >= b.length ? a : b);
  return finalizeKtp(
    f,
    nikDigits: digits,
    province: ranked.map((p) => p.province).nonNulls.firstOrNull,
    unsure: unsure,
  );
}

/// Lengkapi dari NIK, cek silang NIK dengan isi kartu, tandai kolom kosong
/// atau ragu, dan nilai keyakinan.
KtpParse finalizeKtp(
  Map<String, String?> fields, {
  String nikDigits = '',
  String? province,
  Set<String> unsure = const {},
}) {
  final f = Map<String, String?>.of(fields);
  final checks = <KtpCheck>[];
  var conflict = false;
  void warn(String field, String message) =>
      checks.add(KtpCheck(field: field, isError: false, message: message));

  // Digit 7-12 NIK = tanggal lahir (+40 untuk perempuan).
  final nik = f['nik'];
  final info = nik == null ? null : decodeNik(nik);
  if (info?.birth != null) {
    final b = info!.birth!;
    final printed = DateTime.tryParse(f['tgl_lahir'] ?? '');
    if (printed == null) {
      f['tgl_lahir'] =
          '${b.year}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}';
      warn('tgl_lahir', 'Diambil dari NIK. Cocokkan dengan KTP.');
    } else if (printed.day != b.day ||
        printed.month != b.month ||
        printed.year % 100 != b.year % 100) {
      conflict = true;
      warn('tgl_lahir', 'Tidak cocok dengan NIK. Salah satu salah baca.');
    }
    if (f['gender'] == null) {
      f['gender'] = info.gender;
      warn('gender', 'Diambil dari NIK. Cocokkan dengan KTP.');
    } else if (f['gender'] != info.gender) {
      conflict = true;
      warn('gender', 'Tidak cocok dengan kode di NIK.');
    }
  }

  // 2 digit awal NIK = kode provinsi di kepala kartu.
  final code = _provinceCode(province);
  if (nik != null && code != null && !nik.startsWith(code)) {
    conflict = true;
    warn(
      'nik',
      'Dua digit awal NIK (${nik.substring(0, 2)}) tidak cocok dengan provinsi di kartu ($code). Periksa angkanya.',
    );
  }

  if (nik == null) {
    checks.add(
      KtpCheck(
        field: 'nik',
        isError: true,
        message: nikDigits.isEmpty
            ? 'NIK tidak terbaca, isi manual.'
            : 'NIK harus 16 digit (terbaca ${nikDigits.length}).',
      ),
    );
  } else if (info?.birth == null) {
    checks.add(
      const KtpCheck(
        field: 'nik',
        isError: true,
        message: 'NIK tidak valid (tanggal lahir di NIK tidak masuk akal).',
      ),
    );
  }

  var missing = 0;
  for (final e in _required.entries) {
    if (e.key == 'nik') continue;
    if (f[e.key] == null) {
      missing++;
      checks.add(
        KtpCheck(
          field: e.key,
          isError: true,
          message: '${e.value} tidak terbaca, isi manual.',
        ),
      );
    }
  }
  for (final k in unsure) {
    if (f[k] != null && !checks.any((c) => c.field == k)) {
      warn(k, 'Huruf kurang jelas di foto. Cocokkan dengan KTP.');
    }
  }

  return KtpParse(
    fields: KtpFields(f),
    checks: checks,
    confident:
        info?.birth != null &&
        !conflict &&
        f['name'] != null &&
        !unsure.contains('nik') &&
        !unsure.contains('name') &&
        unsure.length <= 2 &&
        missing <= 2,
    nikDigits: nikDigits,
    province: province,
    unsure: unsure,
  );
}

class _Row {
  _Row(OcrLine first) : lines = [first], cy = first.cy;
  final List<OcrLine> lines;
  double cy;

  double get left => lines.map((l) => l.left).reduce(math.min);

  /// Keyakinan baris = yang terendah di antara potongannya.
  double get confidence => lines.map((l) => l.confidence).reduce(math.min);

  String get text {
    final sorted = [...lines]..sort((a, b) => a.left.compareTo(b.left));
    return sorted
        .map((l) => l.text)
        .join(' ')
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

List<_Row> _groupRows(List<OcrLine> lines) {
  if (lines.isEmpty) return const [];
  final heights = lines.map((l) => l.height).toList()..sort();
  final tol = heights[heights.length ~/ 2] * 0.6;
  final sorted = [...lines]..sort((a, b) => a.cy.compareTo(b.cy));
  final rows = <_Row>[];
  for (final l in sorted) {
    final row = rows.isEmpty ? null : rows.last;
    if (row != null && (l.cy - row.cy).abs() <= tol) {
      row.lines.add(l);
      row.cy =
          row.lines.map((x) => x.cy).reduce((a, b) => a + b) / row.lines.length;
    } else {
      rows.add(_Row(l));
    }
  }
  return rows;
}

/// Huruf saja, dengan angka yang mirip huruf dikembalikan ke hurufnya.
String _toLetters(String s) {
  const map = {'0': 'O', '1': 'I', '5': 'S', '8': 'B', '4': 'A', '6': 'G'};
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final m = map[ch] ?? ch;
    if (RegExp(r'[A-Z]').hasMatch(m)) b.write(m);
  }
  return b.toString();
}

/// Angka saja, dengan huruf yang mirip angka dikembalikan ke angkanya.
String _digits(String s) {
  const map = {
    'O': '0',
    'D': '0',
    'Q': '0',
    'I': '1',
    'L': '1',
    '|': '1',
    '!': '1',
    'Z': '2',
    'S': '5',
    'B': '8',
    'G': '6',
    'T': '7',
    'A': '4',
  };
  final b = StringBuffer();
  for (final ch in s.toUpperCase().split('')) {
    final m = map[ch] ?? ch;
    if (RegExp(r'\d').hasMatch(m)) b.write(m);
  }
  return b.toString();
}

/// Cocokkan awal baris dengan label KTP (toleran salah baca); kembalikan
/// label & teks nilai sesudahnya.
(_L, String)? _matchLabel(String text) {
  // Peta indeks huruf -> posisi di teks asli, untuk memotong nilai.
  final letters = StringBuffer();
  final at = <int>[];
  const map = {'0': 'O', '1': 'I', '5': 'S', '8': 'B'};
  for (var i = 0; i < text.length; i++) {
    // "rn" sering terbaca untuk "m" (AGARNA = AGAMA).
    if (text[i] == 'R' && i + 1 < text.length && text[i + 1] == 'N') {
      letters.write('M');
      at.add(++i);
      continue;
    }
    final ch = map[text[i]] ?? text[i];
    if (RegExp(r'[A-Z]').hasMatch(ch)) {
      letters.write(ch);
      at.add(i);
    }
    if (letters.length >= 24) break;
  }
  final ls = letters.toString();
  for (final e in _labels.entries) {
    for (final label in e.value) {
      final tol = label.length <= 4 ? 0 : (label.length <= 8 ? 1 : 2);
      // Panjang awalan yang paling mirip label; seri -> panjang label. Tanpa
      // ini huruf pertama nilai bisa ikut "dimakan" label (SUMENEP -> UMENEP).
      int? n;
      var best = tol + 1;
      for (final k in [label.length, label.length - 1, label.length + 1]) {
        if (k <= 0 || k > ls.length) continue;
        final d = _distance(ls.substring(0, k), label);
        if (d < best) {
          best = d;
          n = k;
        }
      }
      if (n != null) {
        var cut = at[n - 1] + 1;
        // Nilai dimulai setelah titik dua bila ada di dekat label.
        final colon = text.indexOf(':', cut);
        if (colon >= 0 && colon - cut <= 3) cut = colon + 1;
        final value = text
            .substring(cut)
            .replaceFirst(RegExp(r'^[\s:;.,=_\-]+'), '')
            .trim();
        return (e.key, value);
      }
    }
  }
  return null;
}

int _distance(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      ].reduce(math.min);
    }
    prev = cur;
  }
  return prev[b.length];
}

String? _clean(String? v, String drop) {
  if (v == null) return null;
  final s = v
      .toUpperCase()
      .replaceAll(RegExp(drop), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s.,\-]+|[\s.,\-]+$'), '')
      .trim();
  return s.length < 2 ? null : s;
}

/// "SUMENEP, 12-05-1990" -> (SUMENEP, 1990-05-12).
(String?, String?) _splitPlaceDate(String v, DateTime now) {
  String place;
  String datePart;
  final comma = v.indexOf(',');
  if (comma >= 0) {
    place = v.substring(0, comma);
    datePart = v.substring(comma + 1);
  } else {
    final m = RegExp(r'\d').firstMatch(v);
    place = m == null ? v : v.substring(0, m.start);
    datePart = m == null ? '' : v.substring(m.start);
  }
  final d = _digits(datePart);
  String? iso;
  // Tanggal tercetak dd-mm-yyyy: 8 digit setelah tanda pisah dibuang.
  if (d.length >= 8) {
    final day = int.parse(d.substring(0, 2));
    final month = int.parse(d.substring(2, 4));
    final year = int.parse(d.substring(4, 8));
    final date = DateTime(year, month, day);
    if (month >= 1 &&
        month <= 12 &&
        date.month == month &&
        year >= 1900 &&
        !date.isAfter(now)) {
      iso =
          '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    }
  }
  return (place.trim().isEmpty ? null : place, iso);
}

String? _rtRw(String? v) {
  if (v == null) return null;
  final m = RegExp(r'([0-9OIL]{1,3})\s*[/\\|]\s*([0-9OIL]{1,3})').firstMatch(v);
  String? a;
  String? b;
  if (m != null) {
    a = _digits(m.group(1)!);
    b = _digits(m.group(2)!);
  } else {
    // Garis miring terbaca sebagai "1": 0011002 -> 001/002.
    final d = _digits(v);
    if (d.length == 6) {
      a = d.substring(0, 3);
      b = d.substring(3);
    } else if (d.length == 7 && d[3] == '1') {
      a = d.substring(0, 3);
      b = d.substring(4);
    }
  }
  if (a == null || b == null || a.isEmpty || b.isEmpty) return null;
  return '${a.padLeft(3, '0')}/${b.padLeft(3, '0')}';
}

String? _agama(String? v) {
  if (v == null) return null;
  final s = _toLetters(v.toUpperCase());
  if (s.contains('ISLA') || s.contains('SLAM')) return 'ISLAM';
  if (s.contains('KATO')) return 'KATOLIK';
  if (s.contains('KRIS') || s.contains('PROTES')) return 'KRISTEN';
  if (s.contains('HIND')) return 'HINDU';
  if (s.contains('BUD')) return 'BUDHA';
  if (s.contains('HUCU') || s.contains('KONG')) return 'KONGHUCU';
  if (s.contains('KEPER')) return 'KEPERCAYAAN';
  return null;
}

String? _status(String? v) {
  if (v == null) return null;
  final s = _toLetters(v.toUpperCase());
  if (s.contains('BELUM')) return 'BELUM KAWIN';
  if (s.contains('HIDUP')) return 'CERAI HIDUP';
  if (s.contains('MATI')) return 'CERAI MATI';
  if (s.contains('KAWIN')) return 'KAWIN';
  return null;
}

String? _provinceCode(String? province) {
  if (province == null) return null;
  final key = province.replaceAll(' ', '');
  String? code;
  var best = 1 << 30;
  for (final e in ktpProvinceCodes.entries) {
    final d = _distance(key, e.key);
    if (d < best && d <= math.max(1, e.key.length ~/ 5)) {
      best = d;
      code = e.value;
    }
  }
  return code;
}

/// Rapikan singkatan alamat yang titiknya sering hilang dibaca OCR.
String? _address(String? v) {
  var s = _dropStray(v);
  if (s == null) return null;
  // "JL." yang terbaca "J" menempel: JTRUNOJOYO -> JL. TRUNOJOYO.
  s = s.replaceFirst(RegExp(r'^J(?=[^AEIOU\s.L][A-Z]{3})'), 'JL. ');
  return s
      .replaceAllMapped(
        RegExp(r'\b(JL|GG|DS|DSN|KP|PERUM|BLK|NO)\.?\s*(?=[A-Z0-9])'),
        (m) => '${m[1]}. ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Buang huruf tunggal tanpa titik di awal (sisa tanda ":" atau tepi kartu,
/// mis. "N KOTA SUMENEP"); inisial bertitik seperti "M. ALI" tetap.
String? _dropStray(String? v) {
  if (v == null) return null;
  final s = v.replaceFirst(
    RegExp(r'^[A-Z0-9](?![.A-Z0-9])\s+(?=[A-Z0-9]{2})'),
    '',
  );
  return s.length < 2 ? null : s;
}

/// Cocokkan ke daftar pekerjaan KTP (abaikan spasi/garis miring yang hilang).
String? _occupation(String? v) {
  if (v == null) return null;
  final key = v.replaceAll(RegExp(r'[^A-Z]'), '');
  String? hit;
  var best = 1 << 30;
  for (final o in ktpOccupations) {
    final d = _distance(key, o.replaceAll(RegExp(r'[^A-Z]'), ''));
    if (d < best) {
      best = d;
      hit = o;
    }
  }
  return best <= math.max(1, key.length ~/ 6) ? hit : v;
}
