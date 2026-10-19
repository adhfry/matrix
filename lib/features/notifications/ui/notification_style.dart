import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';

/// Ikon & warna per kategori notifikasi (palet MATRIX, DESIGN.md §12).
({IconData icon, Hue hue, String label}) notificationStyle(
  BuildContext context,
  String category,
) {
  final h = context.hues;
  final c = context.mx;
  return switch (category) {
    'absensi' => (
      icon: Icons.fingerprint_rounded,
      hue: Hue(c.primary, c.primaryContainer),
      label: 'Absensi',
    ),
    'jadwal' => (
      icon: Icons.calendar_month_rounded,
      hue: h.indigo,
      label: 'Jadwal',
    ),
    'jaspel' => (icon: Icons.payments_outlined, hue: h.gold, label: 'Jaspel'),
    'izin' => (icon: Icons.event_busy_outlined, hue: h.purple, label: 'Izin'),
    'tukar_jadwal' => (
      icon: Icons.swap_horiz_rounded,
      hue: h.orange,
      label: 'Tukar jadwal',
    ),
    'chat' ||
    'chat_semua' => (icon: Icons.forum_outlined, hue: h.sky, label: 'Chat'),
    'rapat' => (icon: Icons.groups_2_outlined, hue: h.pink, label: 'Rapat'),
    _ => (icon: Icons.campaign_outlined, hue: h.slate, label: 'Sistem'),
  };
}

/// Filter kotak masuk; absensi & chat hanya push, tidak disimpan di kotak masuk.
const inboxFilters = <(String?, String)>[
  (null, 'Semua'),
  ('unread', 'Belum dibaca'),
  ('jadwal', 'Jadwal'),
  ('jaspel', 'Jaspel'),
  ('izin', 'Izin'),
  ('tukar_jadwal', 'Tukar jadwal'),
  ('rapat', 'Rapat'),
  ('sistem', 'Sistem'),
];
