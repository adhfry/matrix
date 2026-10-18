import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/features/scanner/logic/ktp_parser.dart';

/// Baris OCR sintetis: kolom label di x=20, kolom nilai di x=260, tinggi 20.
List<OcrLine> card(List<(String, String?)> rows, {bool splitBlocks = true}) {
  final out = <OcrLine>[];
  var y = 0.0;
  for (final (label, value) in rows) {
    if (value == null) {
      out.add(OcrLine(label, 20, y, 600, y + 20));
    } else if (splitBlocks) {
      out.add(OcrLine(label, 20, y + 1, 200, y + 21));
      out.add(OcrLine(value, 260, y, 640, y + 20));
    } else {
      out.add(OcrLine('$label $value', 20, y, 640, y + 20));
    }
    y += 32;
  }
  return out;
}

final _now = DateTime(2026, 10, 18);

void main() {
  test('KTP bersih: label & nilai sebagai blok terpisah', () {
    final r = parseKtp(
      card([
        ('PROVINSI JAWA TIMUR', null),
        ('KABUPATEN SUMENEP', null),
        ('NIK', ': 3529014512900003'),
        ('Nama', ': SITI AMINAH'),
        ('Tempat/Tgl Lahir', ': SUMENEP, 05-12-1990'),
        ('Jenis Kelamin', ': PEREMPUAN   Gol. Darah : O'),
        ('Alamat', ': JL. TRUNOJOYO NO. 12'),
        ('RT/RW', ': 003/005'),
        ('Kel/Desa', ': PANGARANGAN'),
        ('Kecamatan', ': KOTA SUMENEP'),
        ('Agama', ': ISLAM'),
        ('Status Perkawinan', ': KAWIN'),
        ('Pekerjaan', ': PELAJAR/MAHASISWA'),
        ('Kewarganegaraan', ': WNI'),
        ('Berlaku Hingga', ': SEUMUR HIDUP'),
      ]),
      now: _now,
    );
    final f = r.fields;
    expect(f['nik'], '3529014512900003');
    expect(f['name'], 'SITI AMINAH');
    expect(f['tempat_lahir'], 'SUMENEP');
    expect(f['tgl_lahir'], '1990-12-05');
    expect(f['gender'], 'P');
    expect(f['golongan_darah'], 'O');
    expect(f['alamat'], 'JL. TRUNOJOYO NO. 12');
    expect(f['rt_rw'], '003/005');
    expect(f['kel_desa'], 'PANGARANGAN');
    expect(f['kecamatan'], 'KOTA SUMENEP');
    expect(f['agama'], 'ISLAM');
    expect(f['status_perkawinan'], 'KAWIN');
    expect(f['pekerjaan'], 'PELAJAR/MAHASISWA');
    expect(r.checks, isEmpty);
    expect(r.confident, isTrue);
  });

  test('salah baca OCR umum tetap terurai', () {
    final r = parseKtp(
      card([
        ('N1K', '3529O1451290OOO3'),
        ('Nama', 'SITI AMINAH'),
        ('Tempat/Tgi Lahir', 'SUMENEP,O5-12-199O'),
        ('Jenis Kelamin', 'PEREMPUAN Gol Darah: 0'),
        ('Alamat', 'DUSUN KRAJAN'),
        ('RT/RW', '0031005'),
        ('KelDesa', 'PANGARANGAN'),
        ('Kecarnatan', 'KOTA SUMENEP'),
        ('Agarna', 'lSLAM'),
        ('Status Perkawinan', 'BELUM KAWIN'),
        ('Pekerjaan', 'WIRASWASTA'),
      ], splitBlocks: false),
      now: _now,
    );
    final f = r.fields;
    expect(f['nik'], '3529014512900003');
    expect(f['tgl_lahir'], '1990-12-05');
    expect(f['golongan_darah'], 'O');
    expect(f['rt_rw'], '003/005');
    expect(f['kecamatan'], 'KOTA SUMENEP');
    expect(f['agama'], 'ISLAM');
    expect(f['status_perkawinan'], 'BELUM KAWIN');
    expect(r.confident, isTrue);
  });

  test('alamat dua baris digabung, baris tanpa label di kolom label tidak', () {
    final lines = card([
      ('NIK', '3529011205900001'),
      ('Nama', 'AHMAD FAUZI'),
      ('Alamat', 'JL. RAYA LENTENG'),
    ])..add(const OcrLine('GG. MELATI NO. 3', 260, 96, 600, 116));
    final r = parseKtp(lines, now: _now);
    expect(r.fields['alamat'], 'JL. RAYA LENTENG GG. MELATI NO. 3');
  });

  test(
    'tanggal lahir & jenis kelamin kosong diisi dari NIK sebagai peringatan',
    () {
      final r = parseKtp(
        card([('NIK', '3529011205900001'), ('Nama', 'AHMAD FAUZI')]),
        now: _now,
      );
      expect(r.fields['tgl_lahir'], '1990-05-12');
      expect(r.fields['gender'], 'L');
      final soft = r.checks.where((c) => !c.isError).map((c) => c.field);
      expect(soft, containsAll(['tgl_lahir', 'gender']));
      expect(r.confident, isFalse, reason: 'banyak kolom kosong -> minta AI');
    },
  );

  test('bukan KTP: tidak yakin, NIK ditandai error', () {
    final r = parseKtp(
      card([('STRUK BELANJA', null), ('TOTAL', '25.000')]),
      now: _now,
    );
    expect(r.fields['nik'], isNull);
    expect(r.confident, isFalse);
    expect(r.checks.first.field, 'nik');
    expect(r.checks.first.isError, isTrue);
  });
}
