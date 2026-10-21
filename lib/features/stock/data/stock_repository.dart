import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

/// Batch barang SENTRA dari label QR.
class StockBatchInfo {
  const StockBatchInfo({
    required this.id,
    required this.batchNumber,
    required this.status,
    required this.remaining,
    required this.itemName,
    this.itemCode,
    this.unit,
    this.expiry,
    this.expired = false,
  });

  final int id;
  final String batchNumber;
  final String status;
  final int remaining;
  final String itemName;
  final String? itemCode;
  final String? unit;
  final DateTime? expiry;
  final bool expired;

  bool get active => status == 'active';
  String get unitLabel => unit ?? 'unit';

  factory StockBatchInfo.fromJson(Map<String, dynamic> j) {
    final item = J.m(j['item']);
    return StockBatchInfo(
      id: J.i(j['id']),
      batchNumber: J.s(j['batch_number']) ?? '-',
      status: J.s(j['status']) ?? 'active',
      remaining: J.i(j['remaining']),
      itemName: J.s(item['name']) ?? 'Barang',
      itemCode: J.s(item['code']),
      unit: J.s(item['unit']),
      expiry: J.date(j['expiry_date']),
      expired: J.b(j['expired']),
    );
  }
}

class StockTakeResult {
  const StockTakeResult({
    required this.transactionId,
    required this.quantity,
    required this.batch,
    this.undoUntil,
  });

  final int transactionId;
  final int quantity;
  final StockBatchInfo batch;
  final DateTime? undoUntil;

  factory StockTakeResult.fromJson(Map<String, dynamic> j) => StockTakeResult(
    transactionId: J.i(j['transaction_id']),
    quantity: J.i(j['quantity']),
    batch: StockBatchInfo.fromJson(J.m(j['batch'])),
    undoUntil: J.dt(j['undo_until'])?.toLocal(),
  );
}

class StockHistoryItem {
  const StockHistoryItem({
    required this.id,
    required this.item,
    required this.quantity,
    required this.at,
    this.unit,
    this.batchNumber,
    this.notes,
    this.quick = false,
    this.undoUntil,
  });

  final int id;
  final String item;
  final int quantity;
  final DateTime at;
  final String? unit;
  final String? batchNumber;
  final String? notes;
  final bool quick;
  final DateTime? undoUntil;

  bool get undoable => undoUntil != null && undoUntil!.isAfter(DateTime.now());

  factory StockHistoryItem.fromJson(Map<String, dynamic> j) => StockHistoryItem(
    id: J.i(j['id']),
    item: J.s(j['item']) ?? 'Barang',
    quantity: J.i(j['quantity']),
    at: J.dt(j['at'])!.toLocal(),
    unit: J.s(j['unit']),
    batchNumber: J.s(j['batch_number']),
    notes: J.s(j['notes']),
    quick: J.b(j['quick']),
    undoUntil: J.dt(j['undo_until'])?.toLocal(),
  );
}

class StockSummaryRow {
  const StockSummaryRow({
    required this.item,
    required this.total,
    required this.times,
    this.unit,
  });
  final String item;
  final int total;
  final int times;
  final String? unit;
}

class StockHistory {
  const StockHistory({
    required this.total,
    required this.summary,
    required this.items,
  });
  final int total;
  final List<StockSummaryRow> summary;
  final List<StockHistoryItem> items;
}

class StockRepository {
  StockRepository(this._api);
  static const _p = ApiClient.prefix;
  final ApiClient _api;
  final _rand = Random.secure();

  Future<StockBatchInfo> verify(String code) async => StockBatchInfo.fromJson(
    J.m(await _api.post('$_p/stock/verify', data: {'code': code})),
  );

  /// [quick] = Scan Cepat: 1 unit, catatan diisi server "Scan Cepat".
  Future<StockTakeResult> take(
    String code, {
    int quantity = 1,
    String? notes,
    bool quick = false,
  }) async {
    final res = await _api.post(
      '$_p/stock/take',
      data: {
        'code': code,
        'quantity': quantity,
        'notes': ?notes,
        'quick': quick,
        // Pengaman kirim ulang: server tidak mengurangi stok dua kali.
        'client_ref':
            '${DateTime.now().microsecondsSinceEpoch}-${_rand.nextInt(1 << 31)}',
      },
    );
    return StockTakeResult.fromJson(J.m(res));
  }

  Future<StockBatchInfo> undo(int transactionId) async =>
      StockBatchInfo.fromJson(
        J.m(await _api.delete('$_p/stock/take/$transactionId')),
      );

  Future<StockHistory> history(DateTime month) async {
    final m = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final d = J.m(await _api.get('$_p/stock/history', query: {'month': m}));
    return StockHistory(
      total: J.i(d['total']),
      summary: J
          .l(d['summary'])
          .map(
            (s) => StockSummaryRow(
              item: J.s(s['item']) ?? 'Barang',
              total: J.i(s['total']),
              times: J.i(s['times']),
              unit: J.s(s['unit']),
            ),
          )
          .toList(),
      items: J.l(d['items']).map(StockHistoryItem.fromJson).toList(),
    );
  }
}

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => StockRepository(ref.watch(apiClientProvider)),
);

final stockHistoryProvider = FutureProvider.autoDispose
    .family<StockHistory, DateTime>(
      (ref, m) => ref.watch(stockRepositoryProvider).history(m),
    );
