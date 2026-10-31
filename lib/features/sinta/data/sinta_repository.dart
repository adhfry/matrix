import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

/// Sapaan harian SINTA (sama dengan web, SintaGreetingService). [chat] =
/// obrolan sudah diluncurkan admin di Dashboard SINTA.
class SintaGreeting {
  const SintaGreeting({
    required this.greeting,
    required this.spoiler,
    required this.voice,
    required this.voiceRev,
    required this.chat,
  });

  factory SintaGreeting.fromJson(Map<String, dynamic> j) => SintaGreeting(
    greeting: J.s(j['greeting']) ?? '',
    spoiler: J.s(j['spoiler']) ?? '',
    voice: J.b(j['voice']),
    voiceRev: J.s(j['voice_rev']) ?? '',
    chat: J.b(j['chat']),
  );

  final String greeting;
  final String spoiler;
  final bool voice;
  final String voiceRev;
  final bool chat;
}

class SintaLink {
  const SintaLink(this.label, this.path);
  final String label;
  final String path;

  static List<SintaLink> list(Object? v) => J
      .l(v)
      .map((l) => SintaLink(J.s(l['label']) ?? '', J.s(l['path']) ?? ''))
      .toList();
}

/// Satu tugas dalam usulan SINTA.
class SintaTask {
  const SintaTask(this.title, this.lines, this.after);

  factory SintaTask.fromJson(Map<String, dynamic> j) => SintaTask(
    J.s(j['title']) ?? 'Tugas',
    J
        .l(j['lines'])
        .map((l) => (J.s(l['label']) ?? '', J.s(l['value']) ?? ''))
        .toList(),
    J.s(j['after']) ?? '',
  );

  final String title;
  final List<(String, String)> lines;
  final String after;
}

/// Usulan yang menunggu konfirmasi pegawai: satu atau beberapa tugas
/// (izin, tukar jadwal, preferensi libur) yang dijalankan sekaligus.
class SintaProposal {
  SintaProposal({
    required this.id,
    required this.title,
    required this.items,
    required this.confirmLabel,
    required this.expiresIn,
  }) : at = DateTime.now();

  factory SintaProposal.fromJson(Map<String, dynamic> j) => SintaProposal(
    id: J.s(j['id']) ?? '',
    title: J.s(j['title']) ?? 'Usulan',
    items: J.l(j['items']).map((t) => SintaTask.fromJson(J.m(t))).toList(),
    confirmLabel: J.s(j['confirm_label']) ?? 'Konfirmasi',
    expiresIn: J.i(j['expires_in'], 900),
  );

  final String id;
  final String title;
  final List<SintaTask> items;
  final String confirmLabel;
  final int expiresIn;
  final DateTime at;

  /// open | busy | done | cancelled | expired
  String status = 'open';

  bool get expired => DateTime.now().difference(at).inSeconds > expiresIn;
}

class SintaReply {
  const SintaReply(this.text, this.links, this.proposal, {this.mood = ''});
  final String text;
  final List<SintaLink> links;
  final SintaProposal? proposal;

  /// Pose SINTA dari server: ide, silang (menolak), laporan, cemas.
  final String mood;
}

class SintaRepository {
  SintaRepository(this._api);
  final ApiClient _api;
  static const _p = ApiClient.prefix;

  /// SINTA disembunyikan pengelola untuk akun ini? (pendamping tidak tampil sama sekali)
  Future<bool> hiddenForAccount() async =>
      J.m(await _api.get('$_p/sinta/status'))['hidden'] == true;

  Future<SintaGreeting> greeting() async =>
      SintaGreeting.fromJson(J.m(await _api.get('$_p/sinta/greeting')));

  /// WAV suara SINTA. [rev] ikut di URL supaya rekaman lama tidak terpakai.
  Future<Uint8List> voice(String part, String rev) => _api.bytes(
    '$_p/sinta/greeting/voice?part=$part&v=${Uri.encodeComponent(rev)}',
  );

  /// Suara dari simpanan HP bila sudah pernah diunduh untuk isi yang sama
  /// ([rev] = penanda teks sapaan hari ini); selain itu diunduh lalu disimpan.
  /// Membuka SINTA berkali-kali tidak mengunduh atau membuat suara lagi.
  Future<Uint8List> cachedVoice(String part, String rev) async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/sinta-voice');
    final safe = rev.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final file = File('${dir.path}/$part-$safe.wav');
    if (safe.isNotEmpty && await file.exists() && await file.length() > 44) {
      return file.readAsBytes();
    }
    final bytes = await voice(part, rev);
    try {
      await dir.create(recursive: true);
      // Simpanan lama (hari sebelumnya) dibuang, cukup isi terbaru.
      await for (final f in dir.list()) {
        if (f is File && f.path.contains('/$part-') && f.path != file.path) await f.delete();
      }
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // Gagal menyimpan bukan masalah: suara tetap diputar.
    }
    return bytes;
  }

  Future<SintaReply> chat(
    List<({String role, String text})> history,
    String pageTitle,
  ) async {
    final d = J.m(
      await _api.post(
        '$_p/sinta/chat',
        data: {
          'messages': [
            for (final m in history) {'role': m.role, 'text': m.text},
          ],
          'page': {'path': 'matrix', 'title': pageTitle},
          'via': 'matrix',
        },
      ),
    );
    final p = d['proposal'];
    return SintaReply(
      J.s(d['reply']) ?? '',
      SintaLink.list(d['links']),
      p is Map ? SintaProposal.fromJson(J.m(p)) : null,
      mood: J.s(d['mood']) ?? '',
    );
  }

  Future<
    ({
      String message,
      List<SintaLink> links,
      List<({String title, bool ok, String message})> results,
    })
  >
  confirm(String id) async {
    final r = await _api.postWithMessage(
      '$_p/sinta/chat/confirm',
      data: {'id': id, 'via': 'matrix'},
    );
    final d = J.m(r.data);
    return (
      message: J.s(d['message']) ?? r.message ?? 'Selesai.',
      links: SintaLink.list(d['links']),
      results: [
        for (final r in J.l(d['results']))
          (
            title: J.s(r['title']) ?? '',
            ok: r['ok'] == true,
            message: J.s(r['message']) ?? '',
          ),
      ],
    );
  }

  /// Angkat telepon SINTA: alamat & token ruang LiveKit.
  Future<({String url, String token})> acceptCall(int id) async {
    final d = J.m(await _api.post('$_p/sinta/calls/$id/accept'));
    return (url: J.s(d['url']) ?? '', token: J.s(d['token']) ?? '');
  }

  /// Tolak: SINTA menjadwal ulang telepon.
  Future<void> declineCall(int id) => _api.post('$_p/sinta/calls/$id/decline');
}

final sintaRepositoryProvider = Provider<SintaRepository>(
  (ref) => SintaRepository(ref.watch(apiClientProvider)),
);
