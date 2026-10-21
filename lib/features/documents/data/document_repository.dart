import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

class DocType {
  const DocType({
    required this.id,
    required this.name,
    this.description,
    this.required = false,
    this.multiple = false,
  });
  final int id;
  final String name;
  final String? description;
  final bool required;
  final bool multiple;

  factory DocType.fromJson(Map<String, dynamic> j) => DocType(
    id: J.i(j['id']),
    name: J.s(j['name']) ?? '-',
    description: J.s(j['description']),
    required: J.b(j['is_required']),
    multiple: J.b(j['allows_multiple']),
  );
}

class DocFile {
  const DocFile({
    required this.id,
    required this.name,
    required this.size,
    this.mime,
    this.url,
    this.uploadedAt,
    this.uploadedBy,
  });
  final int id;
  final String name;
  final int size;
  final String? mime;
  final String? url;
  final DateTime? uploadedAt;
  final String? uploadedBy;

  bool get isPdf =>
      mime == 'application/pdf' || name.toLowerCase().endsWith('.pdf');

  factory DocFile.fromJson(Map<String, dynamic> j) => DocFile(
    id: J.i(j['id']),
    name: J.s(j['name']) ?? 'berkas',
    size: J.i(j['size']),
    mime: J.s(j['mime']),
    url: J.s(j['url']),
    uploadedAt: J.dt(j['uploaded_at'])?.toLocal(),
    uploadedBy: J.s(j['uploaded_by']),
  );
}

/// Satu jenis berkas: [status] 'ada', 'tidak_ada', atau null (belum diisi).
class DocItem {
  const DocItem({required this.type, this.status, this.files = const []});
  final DocType type;
  final String? status;
  final List<DocFile> files;

  bool get filled => status != null;
  bool get absent => status == 'tidak_ada';

  factory DocItem.fromJson(Map<String, dynamic> j) => DocItem(
    type: DocType.fromJson(J.m(j['type'])),
    status: J.s(j['status']),
    files: J.l(j['files']).map(DocFile.fromJson).toList(),
  );
}

class DocOverview {
  const DocOverview({
    required this.items,
    required this.done,
    required this.total,
    required this.percent,
    required this.maxBytes,
  });
  final List<DocItem> items;
  final int done;
  final int total;
  final int percent;
  final int maxBytes;

  bool get complete => percent >= 100;

  factory DocOverview.fromJson(Map<String, dynamic> j) {
    final c = J.m(j['completeness']);
    return DocOverview(
      items: J.l(j['items']).map(DocItem.fromJson).toList(),
      done: J.i(c['done']),
      total: J.i(c['total']),
      percent: J.i(c['percent']),
      maxBytes: J.i(J.m(j['limits'])['max_bytes'], 10 * 1024 * 1024),
    );
  }
}

/// Berkas pribadi pegawai (sama dengan menu Berkas Saya di web SiLAKES).
class DocumentRepository {
  DocumentRepository(this._api);
  final ApiClient _api;
  static const _p = ApiClient.prefix;

  Future<DocOverview> overview() async =>
      DocOverview.fromJson(J.m(await _api.get('$_p/my-documents')));

  Future<void> upload(
    int typeId,
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
      ),
    });
    await _api.post(
      '$_p/my-documents/$typeId/files',
      data: form,
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );
  }

  Future<void> removeFile(int fileId) =>
      _api.delete('$_p/my-documents/files/$fileId');

  Future<void> setAbsent(int typeId, bool absent) async {
    await _api.putWithMessage(
      '$_p/my-documents/$typeId/absent',
      data: {'absent': absent},
    );
  }
}

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => DocumentRepository(ref.watch(apiClientProvider)),
);

final documentsProvider = FutureProvider.autoDispose<DocOverview>(
  (ref) => ref.watch(documentRepositoryProvider).overview(),
);
