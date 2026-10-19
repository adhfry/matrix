import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app.dart';
import '../leave/ui/leave_screen.dart';
import '../swap/ui/swap_screen.dart';
import '../shell/home_shell.dart';
import 'ui/notifications_screen.dart';

/// Buka tujuan notifikasi. [route] dari server, mis. "jaspel?month=09-2026",
/// "schedule?month=2026-11", "attendance", "leave", "chat?conversation=5",
/// "web". Chat & "web" dibuka di SiLAKES web ([webUrl]); tujuan tak dikenal
/// -> kotak masuk.
/// [goTab] memindah tab beranda (dari layanan maupun widget).
Future<void> openNotificationRoute({
  required void Function(int tab) goTab,
  void Function(DateTime month)? jumpMonth,
  String? route,
  String? webUrl,
  bool fromInbox = false,
}) async {
  final nav = rootNavigatorKey.currentState;
  if (nav == null) return;
  final uri = Uri.tryParse(route ?? '');
  final path = uri?.path ?? '';

  void toTab(int tab) {
    nav.popUntil((r) => r.isFirst);
    goTab(tab);
  }

  switch (path) {
    case 'jaspel':
      toTab(Tabs.kinerja);
    case 'schedule':
      // "schedule?month=2026-11" -> buka bulan itu.
      final m = DateTime.tryParse('${uri?.queryParameters['month'] ?? ''}-01');
      if (m != null) jumpMonth?.call(m);
      toTab(Tabs.schedule);
    case 'attendance':
      toTab(Tabs.home);
    case 'leave':
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const LeaveScreen()),
      );
    case 'swap':
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => SwapScreen(
            focusId: int.tryParse(uri?.queryParameters['id'] ?? ''),
          ),
        ),
      );
    // Chat & halaman yang hanya ada di SiLAKES web (persetujuan admin, rapat).
    case 'chat' || 'web' when webUrl != null && webUrl.isNotEmpty:
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    default:
      if (!fromInbox) {
        await nav.push(
          MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
        );
      }
  }
}
