// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../services/auth_service.dart';
// import '../services/notes_service.dart';
// import 'note_editor_page.dart';
//
// class NotesListPage extends StatefulWidget {
//   static const route = '/notes';
//   const NotesListPage({super.key});
//
//   @override
//   State<NotesListPage> createState() => _NotesListPageState();
// }
//
// class _NotesListPageState extends State<NotesListPage> {
//   final _svc = NotesService();
//   bool _newestFirst = true;
//
//   String _fmt(DateTime d) => DateFormat('d MMM yyyy HH:mm').format(d);
//
//   // Brand colors to match your other pages
//   static const _brand = Color(0xFF2B384C);
//   static const _onBrand = Color(0xFFF0F4F3);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Notes'),
//         actions: [
//           IconButton(
//             tooltip: _newestFirst ? 'Sort oldest' : 'Sort newest',
//             icon: const Icon(Icons.sort),
//             onPressed: () => setState(() => _newestFirst = !_newestFirst),
//           ),
//           IconButton(
//             tooltip: 'Sign out',
//             icon: const Icon(Icons.logout),
//             onPressed: () async => AuthService().signOut(),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => Navigator.of(context).push(
//           MaterialPageRoute(builder: (_) => const NoteEditorPage()),
//         ),
//         child: const Icon(Icons.add),
//       ),
//       body: StreamBuilder<List<NoteModel>>(
//         stream: _svc.streamNotes(newestFirst: _newestFirst),
//         builder: (context, snap) {
//           if (!snap.hasData) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           final notes = snap.data!;
//           if (notes.isEmpty) {
//             return const Center(child: Text('No notes yet. Tap + to add.'));
//           }
//           return ListView.separated(
//             padding: const EdgeInsets.all(12),
//             itemBuilder: (_, i) {
//               final n = notes[i];
//               final thumb = (n.images.isNotEmpty) ? n.images.first : null;
//               return Dismissible(
//                 key: ValueKey(n.id),
//                 background: Container(color: Colors.red, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 16), child: const Icon(Icons.delete, color: Colors.white)),
//                 secondaryBackground: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
//                 onDismissed: (_) => _svc.delete(n.id),
//                 child: ListTile(
//                   onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorPage(noteId: n.id))),
//                   leading: ClipRRect(
//                     borderRadius: BorderRadius.circular(8),
//                     child: thumb == null
//                         ? Container(width: 56, height: 56, color: Colors.grey.shade200, child: const Icon(Icons.image, color: Colors.grey))
//                         : Image.network(thumb, width: 56, height: 56, fit: BoxFit.cover),
//                   ),
//                   title: Text(n.jobId.isEmpty ? 'Job ID' : n.jobId, style: const TextStyle(fontWeight: FontWeight.w600)),
//                   subtitle: Text(n.text.isEmpty ? '(No text)' : n.text, maxLines: 2, overflow: TextOverflow.ellipsis),
//                   trailing: Text(_fmt(n.createdAt), style: const TextStyle(color: Colors.grey)),
//                 ),
//               );
//             },
//             separatorBuilder: (_, __) => const SizedBox(height: 8),
//             itemCount: notes.length,
//           );
//         },
//       ),
//     );
//   }
// }
/*
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/notes_service.dart';
import '../services/note_model.dart';
import 'note_editor_page.dart';

import 'dart:convert';
import 'package:flutter/widgets.dart';

Widget _imageThumb(String source) {
  if (source.startsWith('data:image/')) {
    final b64 = source.substring(source.indexOf(',') + 1);
    final bytes = base64Decode(b64);
    return Image.memory(bytes, fit: BoxFit.cover);
  } else {
    return Image.network(source, fit: BoxFit.cover);
  }
}

class NotesListPage extends StatefulWidget {
  static const route = '/notes';
  const NotesListPage({super.key});

  @override
  State<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends State<NotesListPage> {
  final _svc = NotesService();
  bool _newestFirst = true;

  // String _fmt(DateTime d) => DateFormat('d MMM yyyy HH:mm').format(d);
  String _fmt(DateTime? d) =>
      d == null ? '—' : DateFormat('d MMM yyyy HH:mm').format(d);

  // Brand colors to match your other pages
  static const _brand = Color(0xFF2B384C);
  static const _onBrand = Color(0xFFF0F4F3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: _brand,
        foregroundColor: _onBrand,
        heroTag: null,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NoteEditorPage()),
        ),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<NoteModel>>(
        stream: _svc.streamNotes(newestFirst: _newestFirst),
        builder: (context, snap) {
          // While loading: show header + a centered spinner
          if (!snap.hasData) {
            return NestedScrollView(
              headerSliverBuilder: (_, __) => [
                _appHeader(context, noteCount: 0),
              ],
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          final notes = snap.data!;
          return NestedScrollView(
            headerSliverBuilder: (_, __) => [
              _appHeader(context, noteCount: notes.length),
            ],
            body: notes.isEmpty
                ? const Center(child: Text('No notes yet. Tap + to add.'))
                : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (_, i) {
                final n = notes[i];
                final thumb = (n.images.isNotEmpty) ? n.images.first : null;
                return Dismissible(
                  key: ValueKey(n.id),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _svc.delete(n.id),
                  child: ListTile(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NoteEditorPage(noteId: n.id),
                      ),
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: thumb == null
                          ? Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image, color: Colors.grey),
                      )
                          : Image.network(thumb, width: 56, height: 56, fit: BoxFit.cover),
                    ),
                    title: Text(
                      n.jobId.isEmpty ? 'Job ID' : n.jobId,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      n.text.isEmpty ? '(No text)' : n.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      _fmt(n.createdAt),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: notes.length,
            ),
          );
        },
      ),
    );
  }

  /// Sliver header to match the look of Service History / Summary pages.
  SliverAppBar _appHeader(BuildContext context, {required int noteCount}) {
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 132,
      backgroundColor: _brand,
      foregroundColor: _onBrand,
      elevation: 1,
      shape: const ContinuousRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      // Collapsed title
      title: const Text('Notes', style: TextStyle(fontWeight: FontWeight.w700)),
      actions: [
        IconButton(
          tooltip: _newestFirst ? 'Sort oldest' : 'Sort newest',
          icon: const Icon(Icons.swap_vert),
          onPressed: () => setState(() => _newestFirst = !_newestFirst),
        ),
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
          onPressed: () async => AuthService().signOut(),
        ),
        const SizedBox(width: 4),
      ],

      // flexibleSpace: FlexibleSpaceBar(
      //   titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
      //   // Expanded title (shows when header is expanded)
      //   title: const Text(
      //     'Notes',
      //     style: TextStyle(fontWeight: FontWeight.w700),
      //   ),
      //   background: Container(
      //     color: _brand,
      //     padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 20),
      //     alignment: Alignment.bottomLeft,
      //     child: Text(
      //       '$noteCount note${noteCount == 1 ? '' : 's'}',
      //       style: const TextStyle(
      //         color: _onBrand,
      //         fontSize: 12,
      //         fontWeight: FontWeight.w500,
      //         letterSpacing: .3,
      //       ),
      //     ),
      //   ),
      // ),
      // Keep a bit of expanded height for a stat line (note count)
      flexibleSpace: const FlexibleSpaceBar(
        // We don't set a second `title` here to avoid duplication/flicker.
        collapseMode: CollapseMode.pin,
      ),

      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(34),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              '$noteCount note${noteCount == 1 ? '' : 's'}',
              style: const TextStyle(
                color: _onBrand,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: .3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
*/

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notes_service.dart';
import '../services/note_model.dart';
import '../ui/image_utils.dart';
import 'note_editor_page.dart';
import 'note_view_page.dart';

class NotesListPage extends StatefulWidget {
  static const route = '/notes';
  const NotesListPage({super.key});
  @override
  State<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends State<NotesListPage> {
  final _svc = NotesService();
  bool _newestFirst = true;

  // keep last successful data to reduce flicker when switching sort
  List<NoteModel>? _cache;

  String _fmt(DateTime? d) =>
      d == null ? '—' : DateFormat('d MMM yyyy HH:mm').format(d);

  static const _brand = Color(0xFF2B384C);
  static const _onBrand = Color(0xFFF0F4F3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: _brand,
        foregroundColor: _onBrand,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NoteEditorPage()),
        ),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<NoteModel>>(
        initialData: _cache, // show previous results while the new query loads
        stream: _svc.streamNotes(newestFirst: _newestFirst),
        builder: (context, snap) {
          // Header builder (service-history look)
          Widget headerBox(int noteCount) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sticky_note_2, color: Colors.indigo, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notes',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$noteCount note${noteCount == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _newestFirst ? 'Sort oldest' : 'Sort newest',
                    icon: const Icon(Icons.swap_vert),
                    onPressed: () => setState(() => _newestFirst = !_newestFirst),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(), // compact like service_history
                  ),
                ],
              ),
            );
          }

          // IMPORTANT: check errors first, otherwise you can get stuck on a spinner
          if (snap.hasError) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: headerBox(_cache?.length ?? 0)),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error loading notes:\n${snap.error}'),
                  ),
                ),
              ],
            );
          }

          // Loading (no data at all)
          if (!snap.hasData) {
            return CustomScrollView(
              slivers: const [
                // show empty header while loading first time
                SliverToBoxAdapter(child: SizedBox(height: 0)),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }

          final notes = snap.data!;
          // update cache (no setState needed)
          _cache = notes;

          if (notes.isEmpty) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: headerBox(0)),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('No notes yet. Tap + to add.')),
                ),
              ],
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: headerBox(notes.length)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) {
                      final n = notes[i];
                      final first = n.imagesB64.isNotEmpty ? n.imagesB64.first : null;

                      return Column(
                        children: [
                          Dismissible(
                            key: ValueKey(n.id),
                            background: _delBg(true),
                            secondaryBackground: _delBg(false),
                            onDismissed: (_) => _svc.delete(n.id),
                            child: ListTile(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => NoteViewPage(noteId: n.id),
                                ),
                              ),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: first == null
                                    ? placeholderThumb()
                                    : smartThumb(first, w: 56, h: 56, fit: BoxFit.cover),
                              ),
                              title: Text(
                                n.jobId.isEmpty ? 'Job ID' : n.jobId,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                n.text.isEmpty ? '(No text)' : n.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                _fmt(n.createdAt),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                    childCount: notes.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _delBg(bool left) => Container(
    color: Colors.red,
    alignment: left ? Alignment.centerLeft : Alignment.centerRight,
    padding: EdgeInsets.only(left: left ? 16 : 0, right: left ? 0 : 16),
    child: const Icon(Icons.delete, color: Colors.white),
  );
}
