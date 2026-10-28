import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app.dart';
import '../chat/ui/chat_list_screen.dart';
import '../chat/ui/chat_thread_screen.dart';
import '../kinerja/ui/kinerja_screen.dart';
import '../leave/ui/leave_detail_screen.dart';
import '../leave/ui/leave_screen.dart';
import '../rapat/ui/rapat_detail_screen.dart';
import '../rapat/ui/rapat_screen.dart';
import '../sid/ui/sid_screen.dart';
import '../swap/ui/swap_screen.dart';
import '../update/ui/update_views.dart';
import '../shell/home_shell.dart';
import 'ui/notifications_screen.dart';

/// Buka tujuan notifikasi. [route] dari server, mis. "jaspel?month=09-2026",
/// "schedule?month=2026-11", "attendance", "leave", "chat?conversation=5",
/// "sid", "rapat?id=5", "web". Rapat dibuka di aplikasi; "web" lainnya dibuka di SiLAKES web ([webUrl]); tujuan tak dikenal
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
      nav.popUntil((r) => r.isFirst);
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const KinerjaScreen()),
      );
    case 'schedule':
      // "schedule?month=2026-11" -> buka bulan itu.
      final m = DateTime.tryParse('${uri?.queryParameters['month'] ?? ''}-01');
      if (m != null) jumpMonth?.call(m);
      toTab(Tabs.schedule);
    case 'attendance':
      toTab(Tabs.home);
    case 'leave':
      // "leave?id=12" -> detail pengajuan; tanpa id -> daftar.
      final id = int.tryParse(uri?.queryParameters['id'] ?? '');
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              id == null ? const LeaveScreen() : LeaveDetailScreen(id: id),
        ),
      );
    // SID diperlukan (mis. SINTA menyiapkan surat izin) -> halaman tanda tangan SID.
    case 'sid':
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const SidScreen()),
      );
    case 'update':
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const UpdateScreen()),
      );
    case 'swap':
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => SwapScreen(
            focusId: int.tryParse(uri?.queryParameters['id'] ?? ''),
          ),
        ),
      );
    // "chat?conversation=5" -> percakapan di aplikasi; tanpa id -> daftar chat.
    case 'chat':
      final id = int.tryParse(uri?.queryParameters['conversation'] ?? '');
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => id == null
              ? const ChatListScreen()
              : ChatThreadScreen(conversationId: id),
        ),
      );
    // Rapat (undangan, pengingat, rapat dimulai) dibuka di aplikasi:
    // server mengirim "web" + alamat /sirapat/meetings/{id} supaya versi lama tetap ke web.
    case 'web' || 'rapat' when meetingIdOf(webUrl, uri) != null:
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => RapatDetailScreen(id: meetingIdOf(webUrl, uri)!),
        ),
      );
    case 'rapat':
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const RapatScreen()),
      );
    // Halaman yang hanya ada di SiLAKES web (persetujuan admin).
    case 'web' when webUrl != null && webUrl.isNotEmpty:
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    default:
      if (!fromInbox) {
        await nav.push(
          MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
        );
      }
  }
}

/// Id rapat dari "rapat?id=5" atau alamat web ".../sirapat/meetings/5".
int? meetingIdOf(String? webUrl, Uri? route) {
  final q = int.tryParse(route?.queryParameters['id'] ?? '');
  if (route?.path == 'rapat' && q != null) return q;
  final m = RegExp(r'/sirapat/meetings/(\d+)').firstMatch(webUrl ?? '');
  return m == null ? null : int.tryParse(m.group(1)!);
}
