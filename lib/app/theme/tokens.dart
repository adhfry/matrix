import 'package:flutter/material.dart';

/// Token warna MATRIX v2 (sumber: DESIGN.md §2).
///
/// Hijau = baik/hadir, rose = masalah nyata, amber = menunggu. Ketiganya tidak
/// pernah dicampur dalam satu gradien.
@immutable
class MxColors extends ThemeExtension<MxColors> {
  const MxColors({
    required this.primary,
    required this.primaryBright,
    required this.primaryContainer,
    required this.onPrimary,
    required this.alert,
    required this.alertContainer,
    required this.pending,
    required this.pendingContainer,
    required this.ink,
    required this.inkMuted,
    required this.surface,
    required this.canvas,
    required this.line,
    required this.heroTop,
    required this.heroBottom,
    required this.onHero,
    required this.onHeroMuted,
    required this.shadow,
  });

  final Color primary;
  final Color primaryBright;
  final Color primaryContainer;
  final Color onPrimary;
  final Color alert;
  final Color alertContainer;
  final Color pending;
  final Color pendingContainer;
  final Color ink;
  final Color inkMuted;
  final Color surface;
  final Color canvas;
  final Color line;

  /// Hero header (DESIGN.md §11): gradien satu warna emerald, teks putih.
  final Color heroTop;
  final Color heroBottom;
  final Color onHero;
  final Color onHeroMuted;

  /// Bayangan kartu; transparan di mode gelap (diganti garis tipis).
  final Color shadow;

  static const light = MxColors(
    primary: Color(0xFF047857),
    primaryBright: Color(0xFF059669),
    primaryContainer: Color(0xFFE7F6EF),
    onPrimary: Color(0xFFFFFFFF),
    alert: Color(0xFFCB213D),
    alertContainer: Color(0xFFFDEDF0),
    pending: Color(0xFFAC4D0E),
    pendingContainer: Color(0xFFFEEEE4),
    ink: Color(0xFF1C2421),
    inkMuted: Color(0xFF5B6661),
    surface: Color(0xFFFFFFFF),
    canvas: Color(0xFFF4F6F4),
    line: Color(0xFFDDE3DF),
    heroTop: Color(0xFF047857),
    heroBottom: Color(0xFF065F46),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFD1FAE5),
    shadow: Color(0x14102A20),
  );

  static const dark = MxColors(
    primary: Color(0xFF34D399),
    primaryBright: Color(0xFF10B981),
    primaryContainer: Color(0xFF0B3B2C),
    onPrimary: Color(0xFF0D1210),
    alert: Color(0xFFF6A6B3),
    alertContainer: Color(0xFF4A1D25),
    pending: Color(0xFFF8AA76),
    pendingContainer: Color(0xFF402615),
    ink: Color(0xFFE8EEEB),
    inkMuted: Color(0xFFA3B0AA),
    surface: Color(0xFF141A17),
    canvas: Color(0xFF0D1210),
    line: Color(0xFF26302B),
    heroTop: Color(0xFF065F46),
    heroBottom: Color(0xFF022C22),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFD1FAE5),
    shadow: Color(0x00000000),
  );

  @override
  MxColors copyWith() => this;

  @override
  MxColors lerp(ThemeExtension<MxColors>? other, double t) {
    if (other is! MxColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return MxColors(
      primary: l(primary, other.primary),
      primaryBright: l(primaryBright, other.primaryBright),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimary: l(onPrimary, other.onPrimary),
      alert: l(alert, other.alert),
      alertContainer: l(alertContainer, other.alertContainer),
      pending: l(pending, other.pending),
      pendingContainer: l(pendingContainer, other.pendingContainer),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      surface: l(surface, other.surface),
      canvas: l(canvas, other.canvas),
      line: l(line, other.line),
      heroTop: l(heroTop, other.heroTop),
      heroBottom: l(heroBottom, other.heroBottom),
      onHero: l(onHero, other.onHero),
      onHeroMuted: l(onHeroMuted, other.onHeroMuted),
      shadow: l(shadow, other.shadow),
    );
  }
}

/// Skala spasi berbasis 4 (DESIGN.md §4).
abstract final class Sp {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Gutter kiri-kanan layar.
  static const double gutter = 16;
}

abstract final class Radii {
  static const double card = 20;
  static const double control = 14;
  static const double hero = 28;
}

/// Durasi gerak (DESIGN.md §7).
abstract final class Motion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 220);
  static const emphasis = Duration(milliseconds: 300);
  static const count = Duration(milliseconds: 700);
  static const stagger = Duration(milliseconds: 60);
  static const curve = Curves.easeOutCubic;

  /// Hormati setelan "kurangi animasi" Android.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : d;
}

extension MxThemeX on BuildContext {
  MxColors get mx => Theme.of(this).extension<MxColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}

/// Satu warna pendukung: [fg] untuk teks/ikon, [bg] untuk latar lembut.
@immutable
class Hue {
  const Hue(this.fg, this.bg);
  final Color fg;
  final Color bg;

  static Hue lerp(Hue a, Hue b, double t) =>
      Hue(Color.lerp(a.fg, b.fg, t)!, Color.lerp(a.bg, b.bg, t)!);
}

/// Palet MATRIX (DESIGN.md §12, permintaan pemilik 2026-10-18). Semua warna
/// diturunkan dari hijau brand & merah logo dengan LUMINANS yang disamakan:
/// tiap [Hue.fg] 5,5:1 terhadap putih (setara hijau brand) dan 4,87:1 terhadap
/// [Hue.bg]-nya, jadi tidak ada warna yang "lebih berat" dari yang lain.
/// Dipakai untuk KATEGORI (jenis shift, jenis layanan, jenis izin). Status
/// tetap: hijau = baik, merah = masalah ([MxColors.alert]), jingga = menunggu.
@immutable
class MxHues extends ThemeExtension<MxHues> {
  const MxHues({
    required this.gold,
    required this.sky,
    required this.indigo,
    required this.purple,
    required this.pink,
    required this.orange,
    required this.slate,
  });

  /// Pagi, poin.
  final Hue gold;

  /// Siang, pasien/scan.
  final Hue sky;

  /// Malam.
  final Hue indigo;

  /// Izin/cuti.
  final Hue purple;

  /// Libur ("tanggal merah" dilunakkan ke merah muda supaya tidak tertukar
  /// dengan merah yang berarti masalah).
  final Hue pink;

  /// Menunggu (sama dengan [MxColors.pending]).
  final Hue orange;

  /// Netral / tanpa jadwal.
  final Hue slate;

  static const light = MxHues(
    gold: Hue(Color(0xFF8D6007), Color(0xFFFDF0D6)),
    sky: Hue(Color(0xFF136EA7), Color(0xFFE4F4FE)),
    indigo: Hue(Color(0xFF4F5CD3), Color(0xFFEFF0FC)),
    purple: Hue(Color(0xFF8947CA), Color(0xFFF5EFFC)),
    pink: Hue(Color(0xFFBC2C80), Color(0xFFFCEDF6)),
    orange: Hue(Color(0xFFAC4D0E), Color(0xFFFEEEE4)),
    slate: Hue(Color(0xFF596B7F), Color(0xFFEEF1F5)),
  );

  static const dark = MxHues(
    gold: Hue(Color(0xFFF4AF26), Color(0xFF372A10)),
    sky: Hue(Color(0xFF72C4F8), Color(0xFF162E3E)),
    indigo: Hue(Color(0xFFB1B8F1), Color(0xFF25294E)),
    purple: Hue(Color(0xFFCEAFEE), Color(0xFF362447)),
    pink: Hue(Color(0xFFF0A5D1), Color(0xFF441F35)),
    orange: Hue(Color(0xFFF8AA76), Color(0xFF402615)),
    slate: Hue(Color(0xFFACBED2), Color(0xFF282C31)),
  );

  @override
  MxHues copyWith() => this;

  @override
  MxHues lerp(ThemeExtension<MxHues>? other, double t) {
    if (other is! MxHues) return this;
    return MxHues(
      gold: Hue.lerp(gold, other.gold, t),
      sky: Hue.lerp(sky, other.sky, t),
      indigo: Hue.lerp(indigo, other.indigo, t),
      purple: Hue.lerp(purple, other.purple, t),
      pink: Hue.lerp(pink, other.pink, t),
      orange: Hue.lerp(orange, other.orange, t),
      slate: Hue.lerp(slate, other.slate, t),
    );
  }
}

extension MxHuesX on BuildContext {
  MxHues get hues => Theme.of(this).extension<MxHues>()!;
}
