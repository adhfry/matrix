import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Merah logo MATRIX. Di layar sebelum masuk (login, pengenalan) dipakai
/// sebagai aksen identitas; di layar data tetap berarti "masalah"
/// (DESIGN.md §13).
const brandRed = Color(0xFFCB213D);

/// Hijau tua latar foto pengenalan (ujung gradien hero MATRIX).
const brandDeep = Color(0xFF04291F);

/// "MATRIX" + lencana v2.
class MatrixWordmark extends StatelessWidget {
  const MatrixWordmark({super.key, this.color = Colors.white, this.size = 28});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MATRIX versi 2',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'MATRIX',
              style: context.text.headlineSmall?.copyWith(
                color: color,
                fontSize: size,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                height: 1.1,
              ),
            ),
            const SizedBox(width: Sp.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: brandRed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'v2',
                style: context.text.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kepanjangan resmi MATRIX dengan huruf pembentuk akronim ditebalkan:
/// Manajemen Absensi Terintegrasi dan Remunerasi Insentif eXpert.
class MatrixAcronym extends StatelessWidget {
  const MatrixAcronym({
    super.key,
    this.strong = Colors.white,
    this.soft = const Color(0xFFB7E4D0),
    this.style,
    this.textAlign,
    this.balanced = false,
  });

  /// Dua baris seimbang ("... Terintegrasi" / "dan ... eXpert") supaya
  /// "eXpert" tidak tertinggal sendirian di baris kedua.
  final bool balanced;

  final Color strong;
  final Color soft;
  final TextStyle? style;
  final TextAlign? textAlign;

  static const _parts = [
    ('M', 'anajemen '),
    ('A', 'bsensi '),
    ('T', 'erintegrasi dan '),
    ('R', 'emunerasi '),
    ('I', 'nsentif '),
    ('', 'e'),
    ('X', 'pert'),
  ];

  static const full =
      'Manajemen Absensi Terintegrasi dan Remunerasi Insentif eXpert';

  @override
  Widget build(BuildContext context) {
    final base = (style ?? context.text.bodyMedium)!.copyWith(color: soft);
    final bold = base.copyWith(color: strong, fontWeight: FontWeight.w700);
    return Text.rich(
      TextSpan(
        children: [
          for (final (head, rest) in _parts) ...[
            if (head.isNotEmpty) TextSpan(text: head, style: bold),
            TextSpan(
              text: balanced && head == 'T' ? 'erintegrasi\ndan ' : rest,
              style: base,
            ),
          ],
        ],
      ),
      semanticsLabel: full,
      textAlign: textAlign,
    );
  }
}
