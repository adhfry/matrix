import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

/// Ruang Dokumen Mutu: Dokumen Kantor (milik bersama), Dokumen Saya, dan
/// isi yang dibagikan seorang rekan.
enum DriveSpace { kantor, saya, shared }

/// Satu folder, berkas, dokumen kantor, atau rekan yang membagikan isi.
/// [type]: kfolder | kdoc | folder | file | person (sama dengan web).
class DriveItem {
  const DriveItem({
    required this.type,
    required this.id,
    required this.name,
    this.ext = '',
    this.mime,
    this.size = 0,
    this.items = 0,
    this.updatedAt,
    this.starred = false,
    this.shared = false,
    this.status,
    this.kindLabel,
    this.location,
    this.ownerId,
  });

  factory DriveItem.fromJson(Map<String, dynamic> j, {int? ownerId}) =>
      DriveItem(
        type: J.s(j['type']) ?? 'file',
        id: J.i(j['id']),
        name: J.s(j['name']) ?? J.s(j['title']) ?? '-',
        ext: (J.s(j['ext']) ?? '').toLowerCase(),
        mime: J.s(j['mime']),
        size: J.i(j['size']),
        items: J.i(j['items']),
        updatedAt: J.dt(j['updated_at'])?.toLocal(),
        starred: J.b(j['starred']),
        shared: j['share'] is Map,
        status: J.s(j['status']),
        kindLabel: J.s(j['kind_label']),
        location: J.s(j['location']),
        ownerId: ownerId,
      );

  final String type;
  final int id;
  final String name;
  final String ext;
  final String? mime;
  final int size;
  final int items;
  final DateTime? updatedAt;
  final bool starred;
  final bool shared;
  final String? status;
  final String? kindLabel;
  final String? location;

  /// Pemilik bila item dibuka dari "dibagikan rekan".
  final int? ownerId;

  bool get isFolder => type == 'folder' || type == 'kfolder';
  bool get isPerson => type == 'person';
  bool get isKantor => type == 'kfolder' || type == 'kdoc';
  bool get isImage => const ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext);
  bool get isPdf => ext == 'pdf' || mime == 'application/pdf';
  String get key => '$type:$id';

  DriveItem copyWith({bool? starred, String? name}) => DriveItem(
    type: type,
    id: id,
    name: name ?? this.name,
    ext: ext,
    mime: mime,
    size: size,
    items: items,
    updatedAt: updatedAt,
    starred: starred ?? this.starred,
    shared: shared,
    status: status,
    kindLabel: kindLabel,
    location: location,
    ownerId: ownerId,
  );
}

class DriveCrumb {
  const DriveCrumb(this.id, this.name);
  final int id;
  final String name;
}

class DriveListing {
  const DriveListing({
    required this.crumbs,
    required this.folders,
    required this.files,
    this.people = const [],
    this.ownerName,
  });

  final List<DriveCrumb> crumbs;
  final List<DriveItem> folders;
  final List<DriveItem> files;
  final List<DriveItem> people;
  final String? ownerName;

  bool get isEmpty => folders.isEmpty && files.isEmpty && people.isEmpty;
}

class DriveHome {
  const DriveHome({
    required this.recentFolders,
    required this.recentFiles,
    required this.starred,
    required this.kantorNew,
  });

  final List<DriveItem> recentFolders;
  final List<DriveItem> recentFiles;
  final List<DriveItem> starred;
  final List<DriveItem> kantorNew;
}

class DriveUsage {
  const DriveUsage({
    required this.used,
    required this.quota,
    required this.maxBytes,
    required this.kantorMaxBytes,
    required this.blocked,
    required this.diskFull,
    required this.publicLinks,
  });

  factory DriveUsage.fromJson(Map<String, dynamic> j) => DriveUsage(
    used: J.i(j['used']),
    quota: J.i(j['quota']),
    maxBytes: J.i(j['max_bytes']),
    kantorMaxBytes: J.i(j['kantor_max_bytes']),
    blocked: [
      for (final e in (j['blocked'] is List ? j['blocked'] as List : const []))
        '$e'.toLowerCase(),
    ],
    diskFull: J.b(j['disk_full']),
    publicLinks: J.b(j['public_links']),
  );

  final int used;
  final int quota;
  final int maxBytes;
  final int kantorMaxBytes;
  final List<String> blocked;
  final bool diskFull;
  final bool publicLinks;
}

class DriveTrashItem {
  const DriveTrashItem({
    required this.id,
    required this.space,
    required this.label,
    required this.kind,
    required this.itemCount,
    this.deletedBy,
    this.deletedAt,
    this.purgeAt,
    required this.canPurge,
  });

  factory DriveTrashItem.fromJson(Map<String, dynamic> j) => DriveTrashItem(
    id: J.i(j['id']),
    space: J.s(j['space']) ?? 'saya',
    label: J.s(j['label']) ?? '-',
    kind: J.s(j['kind']) ?? '',
    itemCount: J.i(j['item_count']),
    deletedBy: J.s(j['deleted_by']),
    deletedAt: J.dt(j['deleted_at'])?.toLocal(),
    purgeAt: J.dt(j['purge_at'])?.toLocal(),
    canPurge: J.b(j['can_purge']),
  );

  final int id;
  final String space;
  final String label;
  final String kind;
  final int itemCount;
  final String? deletedBy;
  final DateTime? deletedAt;
  final DateTime? purgeAt;
  final bool canPurge;
}

/// Tautan berbagi milik sendiri (Dokumen Saya).
class DriveShareInfo {
  const DriveShareInfo({
    this.id,
    this.audience,
    this.expiresAt,
    this.url,
    this.accessCount = 0,
    required this.publicLinks,
    required this.maxDays,
  });

  factory DriveShareInfo.fromJson(Map<String, dynamic> j) {
    final s = j['share'] is Map ? J.m(j['share']) : null;
    final active = s != null && J.b(s['active']);
    return DriveShareInfo(
      id: active ? J.i(s['id']) : null,
      audience: active ? J.s(s['audience']) : null,
      expiresAt: active ? J.dt(s['expires_at'])?.toLocal() : null,
      url: active ? J.s(s['url']) : null,
      accessCount: s == null ? 0 : J.i(s['access_count']),
      publicLinks: J.b(j['public_links']),
      maxDays: J.i(j['max_days'], 90),
    );
  }

  final int? id;
  final String? audience;
  final DateTime? expiresAt;
  final String? url;
  final int accessCount;
  final bool publicLinks;
  final int maxDays;

  bool get active => id != null;
}

class DriveSearchResult {
  const DriveSearchResult(this.kantor, this.saya);
  final List<DriveItem> kantor;
  final List<DriveItem> saya;
}

class DriveRepository {
  DriveRepository(this._api);
  final ApiClient _api;
  static const _p = '${ApiClient.prefix}/drive';

  List<DriveItem> _items(Object? v, {int? ownerId}) =>
      J.l(v).map((j) => DriveItem.fromJson(j, ownerId: ownerId)).toList();

  Future<DriveUsage> usage() async =>
      DriveUsage.fromJson(J.m(await _api.get('$_p/usage')));

  Future<DriveHome> home() async {
    final d = J.m(await _api.get('$_p/home'));
    return DriveHome(
      recentFolders: _items(d['recent_folders']),
      recentFiles: _items(d['recent_files']),
      starred: _items(d['starred']),
      kantorNew: _items(d['kantor_new']),
    );
  }

  Future<DriveListing> listing(
    DriveSpace space, {
    int? folder,
    int? ownerId,
  }) async {
    final path = switch (space) {
      DriveSpace.kantor => '$_p/kantor',
      DriveSpace.saya => '$_p/saya',
      DriveSpace.shared => '$_p/shared/$ownerId',
    };
    final d = J.m(
      await _api.get(path, query: {'folder': ?folder}),
    );
    final owner = space == DriveSpace.shared ? ownerId : null;
    return DriveListing(
      crumbs: [
        for (final c in J.l(d['crumbs']))
          DriveCrumb(J.i(c['id']), J.s(c['name']) ?? '-'),
      ],
      folders: _items(d['folders'], ownerId: owner),
      files: _items(d['files'], ownerId: owner),
      people: _items(d['people']),
      ownerName: d['owner'] is Map ? J.s(J.m(d['owner'])['name']) : null,
    );
  }

  /// Cari di Dokumen Kantor (judul, nomor, isi) dan Dokumen Saya (nama).
  Future<DriveSearchResult> search(String q) async {
    final res = await Future.wait([
      _api.get('${ApiClient.prefix}/quality-docs/search', query: {'q': q}),
      _api.get('$_p/search', query: {'q': q}),
    ]);
    final k = J.m(res[0]);
    final s = J.m(res[1]);
    return DriveSearchResult(
      [
        for (final f in J.l(k['folders']))
          DriveItem(
            type: 'kfolder',
            id: J.i(f['id']),
            name: J.s(f['name']) ?? '-',
            location: J.s(f['path']),
          ),
        for (final d in J.l(k['documents']))
          DriveItem(
            type: 'kdoc',
            id: J.i(d['id']),
            name: J.s(d['title']) ?? '-',
            status: J.s(d['status']),
            kindLabel: J.s(d['kind_label']),
            location: J.s(d['folder_path']),
          ),
      ],
      [..._items(s['folders']), ..._items(s['files'])],
    );
  }

  /// Tautan sementara isi berkas (30 menit): [inline] untuk pratinjau.
  Future<({String url, String name})> fileUrl(
    DriveItem item, {
    bool inline = true,
  }) async {
    if (item.type == 'kdoc') {
      final d = J.m(await _api.get('${ApiClient.prefix}/quality-docs/${item.id}'));
      return (url: J.s(d['url']) ?? '', name: J.s(d['original_name']) ?? item.name);
    }
    if (inline) {
      final d = J.m(await _api.get('$_p/files/${item.id}'));
      return (url: J.s(d['url']) ?? '', name: item.name);
    }
    final d = J.m(await _api.get('$_p/download/${item.type}/${item.id}'));
    return (url: J.s(d['url']) ?? '', name: item.name);
  }

  /// Unduh isi berkas ke [savePath] (pratinjau PDF di aplikasi).
  Future<void> downloadTo(String url, String savePath) =>
      Dio().download(url, savePath);

  Future<void> touch(DriveItem i) =>
      _api.post('$_p/touch', data: {'type': i.type, 'id': i.id});

  Future<bool> star(DriveItem i) async {
    final d = J.m(
      await _api.post('$_p/star', data: {'type': i.type, 'id': i.id}),
    );
    return J.b(d['starred']);
  }

  Future<String?> createFolder(DriveSpace space, int? parent, String name) async =>
      (await _api.postWithMessage(
        '$_p/folders',
        data: {'space': space.name, 'parent_id': parent, 'name': name},
      )).message;

  Future<String?> rename(DriveItem i, String name) async =>
      (await _api.postWithMessage(
        '$_p/rename',
        data: {'type': i.type, 'id': i.id, 'name': name},
      )).message;

  Future<String?> move(
    DriveSpace space,
    List<DriveItem> items,
    int? target, {
    int? contextId,
  }) async => (await _api.postWithMessage(
    '$_p/move',
    data: {
      'space': space.name,
      'items': [
        for (final i in items) {'type': i.type, 'id': i.id},
      ],
      'target_id': target,
      'context_id': contextId,
    },
  )).message;

  /// Pindahkan ke Sampah; mengembalikan id Sampah untuk tombol Urungkan.
  Future<({int trashId, String? message})> trash(
    DriveSpace space,
    List<DriveItem> items, {
    int? contextId,
  }) async {
    final r = await _api.postWithMessage(
      '$_p/trash',
      data: {
        'space': space.name,
        'items': [
          for (final i in items) {'type': i.type, 'id': i.id},
        ],
        'context_id': contextId,
      },
    );
    return (trashId: J.i(J.m(r.data)['trash_id']), message: r.message);
  }

  Future<List<DriveTrashItem>> trashList() async =>
      J.l(await _api.get('$_p/trash')).map(DriveTrashItem.fromJson).toList();

  Future<String?> restore(int trashId) async =>
      (await _api.postWithMessage('$_p/trash/$trashId/restore')).message;

  Future<void> purge(int trashId) => _api.delete('$_p/trash/$trashId');

  Future<void> emptyTrash() => _api.delete('$_p/trash');

  Future<DriveShareInfo> share(DriveItem i) async =>
      DriveShareInfo.fromJson(J.m(await _api.get('$_p/share/${i.type}/${i.id}')));

  Future<String?> saveShare(
    DriveItem i,
    String audience,
    DateTime expires,
  ) async => (await _api.putWithMessage(
    '$_p/share/${i.type}/${i.id}',
    data: {
      'audience': audience,
      'expires_at':
          '${expires.year}-${expires.month.toString().padLeft(2, '0')}-${expires.day.toString().padLeft(2, '0')}',
    },
  )).message;

  Future<void> revokeShare(int shareId) => _api.delete('$_p/shares/$shareId');

  /// Unggah ke Dokumen Saya ([folder] null = akar) atau Dokumen Kantor.
  Future<void> upload(
    DriveSpace space,
    int? folder,
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final name = file.uri.pathSegments.last;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: name),
      if (space == DriveSpace.saya && folder != null) 'folder_id': folder,
      if (space == DriveSpace.kantor && folder != null) 'folder_ids[]': folder,
    });
    await _api.post(
      space == DriveSpace.kantor
          ? '${ApiClient.prefix}/quality-docs'
          : '$_p/upload',
      data: form,
      onSendProgress: onProgress,
    );
  }
}

final driveRepositoryProvider = Provider<DriveRepository>(
  (ref) => DriveRepository(ref.watch(apiClientProvider)),
);

final driveUsageProvider = FutureProvider.autoDispose<DriveUsage>(
  (ref) => ref.watch(driveRepositoryProvider).usage(),
);

final driveHomeProvider = FutureProvider.autoDispose<DriveHome>(
  (ref) => ref.watch(driveRepositoryProvider).home(),
);

typedef DriveLocation = ({DriveSpace space, int? folder, int? owner});

final driveListingProvider = FutureProvider.autoDispose
    .family<DriveListing, DriveLocation>(
      (ref, l) => ref
          .watch(driveRepositoryProvider)
          .listing(l.space, folder: l.folder, ownerId: l.owner),
    );

final driveTrashProvider = FutureProvider.autoDispose<List<DriveTrashItem>>(
  (ref) => ref.watch(driveRepositoryProvider).trashList(),
);
