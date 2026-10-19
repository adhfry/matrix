import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

/// Kemampuan & status NFC di HP ini (dari NfcTapChannel.kt).
class NfcTapLocal {
  const NfcTapLocal({
    required this.nfc,
    required this.hce,
    required this.nfcOn,
    required this.screenOff,
    required this.installed,
    required this.enabled,
    required this.deviceUuid,
    required this.deviceModel,
  });

  /// HP punya NFC.
  final bool nfc;

  /// HP bisa bertindak sebagai kartu (Host Card Emulation).
  final bool hce;

  /// NFC sedang dinyalakan di pengaturan.
  final bool nfcOn;

  /// Android 14+: tap tetap jalan saat layar mati (bila HP mengizinkan).
  final bool screenOff;

  /// Kunci tap tersimpan di HP ini.
  final bool installed;
  final bool enabled;
  final String deviceUuid;
  final String deviceModel;

  bool get supported => nfc && hce;

  factory NfcTapLocal.fromMap(Map<dynamic, dynamic> m) => NfcTapLocal(
    nfc: m['nfc'] == true,
    hce: m['hce'] == true,
    nfcOn: m['nfcOn'] == true,
    screenOff: m['screenOff'] == true,
    installed: m['installed'] == true,
    enabled: m['enabled'] == true,
    deviceUuid: m['deviceUuid'] as String? ?? '',
    deviceModel: m['deviceModel'] as String? ?? 'HP ini',
  );

  /// Bukan Android / platform tanpa kanal (mis. tes): anggap tidak didukung.
  static const none = NfcTapLocal(
    nfc: false,
    hce: false,
    nfcOn: false,
    screenOff: false,
    installed: false,
    enabled: false,
    deviceUuid: '',
    deviceModel: 'HP ini',
  );
}

/// HP alat tap yang tercatat di server.
class NfcTapDevice {
  const NfcTapDevice({
    required this.deviceUuid,
    this.deviceModel,
    required this.enabled,
    this.enrolledAt,
    this.lastUsedAt,
  });

  final String deviceUuid;
  final String? deviceModel;
  final bool enabled;
  final DateTime? enrolledAt;
  final DateTime? lastUsedAt;

  factory NfcTapDevice.fromJson(Map<String, dynamic> j) => NfcTapDevice(
    deviceUuid: J.s(j['device_uuid']) ?? '',
    deviceModel: J.s(j['device_model']),
    enabled: j['enabled'] == true,
    enrolledAt: J.dt(j['enrolled_at']),
    lastUsedAt: J.dt(j['last_used_at']),
  );
}

/// Gabungan status lokal + server untuk halaman pengaturan.
class NfcTapState {
  const NfcTapState({required this.local, required this.hasCard, this.device});

  final NfcTapLocal local;

  /// Admin sudah mendaftarkan kartu absen untuk akun ini.
  final bool hasCard;

  /// HP yang terdaftar untuk akun ini (bisa HP lain).
  final NfcTapDevice? device;

  /// HP ini yang terdaftar dan kuncinya ada di HP ini.
  bool get thisPhoneActive =>
      device != null &&
      local.installed &&
      device!.deviceUuid == local.deviceUuid;

  /// Akun ini terdaftar memakai HP lain.
  bool get otherPhone =>
      device != null && device!.deviceUuid != local.deviceUuid;
}

class NfcTapRepository {
  NfcTapRepository(this._api, [MethodChannel? channel])
    : _ch = channel ?? const MethodChannel('matrix/nfc_tap');

  final ApiClient _api;
  final MethodChannel _ch;
  static const _p = ApiClient.prefix;

  Future<NfcTapLocal> local() async {
    try {
      final m = await _ch.invokeMethod<Map<dynamic, dynamic>>('status');
      return m == null ? NfcTapLocal.none : NfcTapLocal.fromMap(m);
    } on MissingPluginException {
      return NfcTapLocal.none;
    }
  }

  Future<NfcTapState> state() async {
    final local = await this.local();
    final d = J.m(await _api.get('$_p/nfc-tap'));
    final dev = J.m(d['device']);
    // Dicabut admin / dihapus dari HP lain: kunci di HP ini tidak berlaku lagi.
    if (local.installed &&
        (dev.isEmpty || J.s(dev['device_uuid']) != local.deviceUuid)) {
      await _ch.invokeMethod('remove');
      return state();
    }
    return NfcTapState(
      local: local,
      hasCard: d['has_card'] == true,
      device: dev.isEmpty ? null : NfcTapDevice.fromJson(dev),
    );
  }

  Future<void> openNfcSettings() => _ch.invokeMethod('openNfcSettings');

  /// Tunggu satu kartu ditempel; null bila dibatalkan.
  Future<String?> readCardUid() => _ch.invokeMethod<String>('readCardUid');

  Future<void> cancelRead() => _ch.invokeMethod('cancelRead');

  /// Cocokkan kartu ke akun di server, lalu simpan kunci di Keystore HP.
  Future<void> enroll(String cardUid, NfcTapLocal local) async {
    final d = J.m(
      await _api.post(
        '$_p/nfc-tap/enroll',
        data: {
          'card_uid': cardUid,
          'device_uuid': local.deviceUuid,
          'device_model': local.deviceModel,
        },
      ),
    );
    await _ch.invokeMethod('install', {
      'secret': J.s(d['secret']),
      'tapId': J.s(d['tap_id']),
    });
  }

  Future<void> setEnabled(bool enabled) async {
    await _api.patch('$_p/nfc-tap', data: {'enabled': enabled});
    await _ch.invokeMethod('setEnabled', {'enabled': enabled});
  }

  Future<void> remove() async {
    await _api.delete('$_p/nfc-tap');
    await _ch.invokeMethod('remove');
  }
}

final nfcTapRepositoryProvider = Provider<NfcTapRepository>(
  (ref) => NfcTapRepository(ref.watch(apiClientProvider)),
);

final nfcTapStateProvider = FutureProvider.autoDispose<NfcTapState>(
  (ref) => ref.watch(nfcTapRepositoryProvider).state(),
);
