import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mx.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';

final _peopleProvider = FutureProvider.autoDispose<List<ChatPerson>>(
  (ref) => ref.watch(chatRepositoryProvider).people(),
);

/// Mulai chat pribadi (ketuk satu nama) atau buat grup (pilih beberapa nama).
/// Mengembalikan id percakapan lewat Navigator.pop.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  String _q = '';
  bool _group = false;
  final _picked = <int>{};
  bool _busy = false;

  Future<void> _direct(ChatPerson p) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = await ref.read(chatRepositoryProvider).startDirect(p.id);
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) showMxSnack(context, '$e', tone: Tone.alert);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createGroup() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctl = TextEditingController();
        return AlertDialog(
          title: const Text('Nama grup'),
          content: TextField(
            controller: ctl,
            autofocus: true,
            maxLength: 255,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Mis. Tim Sampling Prolanis'),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Buat grup')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final id = await ref.read(chatRepositoryProvider).createGroup(name, _picked.toList());
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) showMxSnack(context, '$e', tone: Tone.alert);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_peopleProvider);
    final c = context.mx;
    return Scaffold(
      appBar: AppBar(title: Text(_group ? 'Grup baru' : 'Chat baru')),
      bottomNavigationBar: _group
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.sm, Sp.gutter, Sp.md),
                child: FilledButton(
                  onPressed: _picked.isEmpty || _busy ? null : _createGroup,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: Text(_picked.isEmpty ? 'Pilih anggota grup' : 'Lanjut, ${_picked.length} anggota'),
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.sm, Sp.gutter, 0),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(hintText: 'Cari nama pegawai', prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          SwitchListTile(
            value: _group,
            onChanged: (v) => setState(() {
              _group = v;
              _picked.clear();
            }),
            secondary: const Icon(Icons.groups_outlined),
            title: const Text('Buat grup'),
            subtitle: const Text('Pilih beberapa pegawai sekaligus'),
          ),
          Divider(height: 1, color: c.line),
          Expanded(
            child: async.when(
              loading: () => StateView.loading('Memuat daftar pegawai…'),
              error: (e, _) => StateView.error(e, onRetry: () => ref.invalidate(_peopleProvider)),
              data: (people) {
                final q = _q.trim().toLowerCase();
                final list = q.isEmpty ? people : people.where((p) => p.name.toLowerCase().contains(q)).toList();
                if (list.isEmpty) {
                  return StateView.empty(icon: Icons.person_search_outlined, title: 'Pegawai tidak ditemukan');
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    final selected = _picked.contains(p.id);
                    return ListTile(
                      enabled: !_busy,
                      leading: NameAvatar(name: p.name, initials: initialsOf(p.name), url: p.photoUrl, size: 44),
                      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: p.jabatan == null ? null : Text(p.jabatan!, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: _group
                          ? Checkbox(
                              value: selected,
                              onChanged: (_) => setState(() => selected ? _picked.remove(p.id) : _picked.add(p.id)),
                            )
                          : null,
                      onTap: _group
                          ? () => setState(() => selected ? _picked.remove(p.id) : _picked.add(p.id))
                          : () => _direct(p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
