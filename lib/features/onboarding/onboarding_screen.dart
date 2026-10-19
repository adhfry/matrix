import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/storage/secure_store.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/matrix_mark.dart';

/// Sudah melihat pengenalan MATRIX v2 di HP ini? Tidak dihapus saat keluar akun.
final onboardedProvider = FutureProvider<bool>(
  (ref) => ref.watch(secureStoreProvider).onboarded(),
);

const _photo = 'assets/images/labkesda_gedung.jpg';
const _front = 'assets/images/labkesda_depan.jpg';

/// Pengenalan sekali di HP baru: sambutan MATRIX v2, profil Labkesda Sumenep,
/// lalu apa yang bisa dilakukan pegawai. Foto gedung menjadi latar yang
/// bergeser pelan antarhalaman; gradien hijau tua naik dari bawah sehingga
/// teks selalu terbaca di atas foto.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _count = 3;
  final _pc = PageController();
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pc.addListener(() => setState(() => _page = _pc.page ?? 0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(_photo), context, onError: (_, _) {});
    precacheImage(const AssetImage(_front), context, onError: (_, _) {});
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    HapticFeedback.lightImpact();
    await ref.read(secureStoreProvider).setOnboarded();
    ref.invalidate(onboardedProvider);
  }

  void _next() {
    if (_page.round() >= _count - 1) {
      _finish();
      return;
    }
    _pc.nextPage(
      duration: Motion.of(context, const Duration(milliseconds: 420)),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final t = (_page / (_count - 1)).clamp(0.0, 1.0);
    // Halaman isi (>= 2) teksnya lebih tinggi: gradien sudah penuh di halaman 2.
    final k = _page.clamp(0.0, 1.0);
    final last = _page.round() == _count - 1;
    final pad = MediaQuery.paddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: brandDeep,
        body: Stack(
          children: [
            // Foto gedung: bergeser ke kanan & sedikit membesar saat digeser.
            Positioned.fill(
              child: Transform.scale(
                scale: still ? 1.0 : 1.0 + 0.06 * t,
                child: Image.asset(
                  _photo,
                  fit: BoxFit.cover,
                  alignment: Alignment(still ? -0.6 : -0.9 + 0.75 * t, -0.2),
                  semanticLabel: 'Gedung UPTD Labkesda Kabupaten Sumenep',
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            // Halaman isi: foto tampak depan memudar masuk menggantikan foto udara.
            Positioned.fill(
              child: Opacity(
                opacity: k,
                child: Image.asset(
                  _front,
                  fit: BoxFit.cover,
                  alignment: Alignment(still ? 0.1 : 0.3 - 0.4 * t, -1),
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            // Gradien transparan -> hijau tua; naik menutup foto di halaman isi.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      brandDeep.withValues(alpha: 0.75 * k),
                      brandDeep.withValues(alpha: 0.88 + 0.08 * k),
                      brandDeep,
                    ],
                    stops: [0, 0.18, 0.62 - 0.32 * k, 0.86 - 0.28 * k],
                  ),
                ),
              ),
            ),
            PageView(
              controller: _pc,
              children: [
                for (var i = 0; i < _count; i++)
                  _PageBody(
                    offset: still ? 0 : _page - i,
                    bottomInset: 132 + pad.bottom,
                    child: switch (i) {
                      0 => const _Welcome(),
                      1 => const _About(),
                      _ => const _Features(),
                    },
                  ),
              ],
            ),
            // Atas: logo + Lewati.
            Positioned(
              top: pad.top + Sp.sm,
              left: Sp.xl,
              right: Sp.sm,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const MatrixMark(size: 28),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: last ? 0 : 1,
                    duration: Motion.of(context, Motion.fast),
                    child: TextButton(
                      onPressed: last ? null : _finish,
                      // Pil gelap: tetap terbaca di atas atap/langit terang.
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black.withValues(alpha: 0.32),
                        padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
                      ),
                      child: const Text('Lewati'),
                    ),
                  ),
                ],
              ),
            ),
            // Bawah: penanda halaman + tombol.
            Positioned(
              left: Sp.xl,
              right: Sp.xl,
              bottom: pad.bottom + Sp.lg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: 'Halaman ${_page.round() + 1} dari $_count',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _count; i++)
                          _Dot(active: 1 - math.min(1, (_page - i).abs())),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sp.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: brandDeep,
                      ),
                      child: AnimatedSwitcher(
                        duration: Motion.of(context, Motion.fast),
                        child: Text(
                          last ? 'Mulai' : 'Lanjut',
                          key: ValueKey(last),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  /// 0..1, 1 = halaman ini sedang tampil.
  final double active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 8 + 20 * active,
      height: 8,
      decoration: BoxDecoration(
        color: Color.lerp(Colors.white38, Colors.white, active),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Isi halaman rata bawah; memudar & bergeser sesuai posisi geser.
class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.offset,
    required this.bottomInset,
    required this.child,
  });

  final double offset;
  final double bottomInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fade = (1 - offset.abs() * 1.6).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Sp.xl,
          MediaQuery.paddingOf(context).top + 72,
          Sp.xl,
          bottomInset,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(
              0,
              box.maxHeight -
                  bottomInset -
                  MediaQuery.paddingOf(context).top -
                  72,
            ),
          ),
          child: Opacity(
            opacity: fade,
            child: Transform.translate(
              offset: Offset(offset * -48, offset.abs() * 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [child],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Garis merah pendek + label kecil di atas judul.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 3,
          decoration: BoxDecoration(
            color: brandRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: Sp.sm),
        Flexible(
          child: Text(
            text,
            style: context.text.labelLarge?.copyWith(
              color: const Color(0xFFD1FAE5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

TextStyle? _title(BuildContext context) => context.text.headlineMedium
    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, height: 1.2);

TextStyle? _body(BuildContext context) =>
    context.text.bodyLarge?.copyWith(color: const Color(0xFFC9E9DB));

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('UPTD Labkesda Kabupaten Sumenep'),
        const SizedBox(height: Sp.lg),
        Semantics(
          header: true,
          child: Text('Selamat datang di', style: _title(context)),
        ),
        const SizedBox(height: Sp.xs),
        const MatrixWordmark(size: 40),
        const SizedBox(height: Sp.lg),
        MatrixAcronym(style: context.text.bodyLarge),
        const SizedBox(height: Sp.md),
        Text(
          'Aplikasi pegawai Labkesda Sumenep. Masuk dengan akun SiLAKES yang sama.',
          style: _body(context),
        ),
      ],
    );
  }
}

class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('Tentang kami'),
        const SizedBox(height: Sp.lg),
        Semantics(
          header: true,
          child: Text(
            'Laboratorium Kesehatan Daerah Kabupaten Sumenep',
            style: _title(context),
          ),
        ),
        const SizedBox(height: Sp.md),
        Text(
          'Unit pelaksana teknis Dinas Kesehatan yang melayani pemeriksaan laboratorium untuk masyarakat dan instansi di Sumenep.',
          style: _body(context),
        ),
        const SizedBox(height: Sp.lg),
        const _Credentials(),
        const SizedBox(height: Sp.xl),
        const _Row(
          icon: Icons.biotech_outlined,
          title: 'Laboratorium klinik',
          text: 'Hematologi dan kimia klinik',
        ),
        const _Row(
          icon: Icons.water_drop_outlined,
          title: 'Kesehatan lingkungan',
          text: 'Uji kualitas air dan makanan',
        ),
        const _Row(
          icon: Icons.medication_outlined,
          title: 'Pemeriksaan narkoba',
          text: 'Untuk perorangan maupun instansi',
        ),
        const SizedBox(height: Sp.sm),
        Row(
          children: [
            const Icon(
              Icons.place_outlined,
              size: 18,
              color: Color(0xFFC9E9DB),
            ),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Text(
                'Jl. Trunojoyo No. 51A, Sumenep · (0328) 6771894',
                style: context.text.bodyMedium?.copyWith(
                  color: const Color(0xFFC9E9DB),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Lambang Kabupaten Sumenep + lencana akreditasi Kemenkes (nomor dari
/// sertifikat yang diberikan pemilik sistem).
class _Credentials extends StatelessWidget {
  const _Credentials();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          for (final (asset, label) in const [
            ('assets/images/lambang_sumenep.png', 'Lambang Kabupaten Sumenep'),
            ('assets/images/kemenkes_mark.png', 'Logo Kementerian Kesehatan'),
          ]) ...[
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Image.asset(asset, semanticLabel: label),
            ),
            const SizedBox(width: Sp.sm),
          ],
          const SizedBox(width: Sp.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Terakreditasi Paripurna',
                  style: context.text.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Kemenkes RI · YM.02.01/D/46629/2024',
                  style: context.text.bodySmall?.copyWith(
                    color: const Color(0xFFC9E9DB),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Features extends StatelessWidget {
  const _Features();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('Sehari di Labkesda'),
        const SizedBox(height: Sp.lg),
        Semantics(
          header: true,
          child: Text(
            'Yang bisa Anda kerjakan di MATRIX',
            style: _title(context),
          ),
        ),
        const SizedBox(height: Sp.xl),
        const _Row(
          icon: Icons.face_retouching_natural_outlined,
          title: 'Datang & pulang',
          text: 'Absen dengan foto wajah. Lokasi dicek dari GPS.',
        ),
        const _Row(
          icon: Icons.calendar_month_outlined,
          title: 'Jadwal shift',
          text: 'Shift sebulan penuh, termasuk perubahan dari admin.',
        ),
        const _Row(
          icon: Icons.event_busy_outlined,
          title: 'Izin, sakit, cuti',
          text: 'Ajukan dari HP. Keputusan admin masuk sebagai notifikasi.',
        ),
        const _Row(
          icon: Icons.badge_outlined,
          title: 'Pasien baru',
          text: 'Foto KTP pasien, periksa hasil bacaan, lalu simpan.',
        ),
        const _Row(
          icon: Icons.insights_outlined,
          title: 'Jam kerja & jaspel',
          text:
              'Rapor bulanan. Nominal jaspel tampil setelah admin menerbitkan.',
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  text,
                  style: context.text.bodySmall?.copyWith(
                    color: const Color(0xFFC9E9DB),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
