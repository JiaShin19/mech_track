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

  // selection state
  final Set<String> _selected = {};
  bool get _selectionMode => _selected.isNotEmpty;

  // cache latest notes for header actions (e.g. select all)
  List<NoteModel> _latest = [];

  // keep last successful data to reduce flicker when switching sort
  List<NoteModel>? _cache;

  String _fmt(DateTime? d) =>
      d == null ? '—' : DateFormat('d MMM yyyy HH:mm').format(d);

  static const _brand = Color(0xFF2B384C);
  static const _onBrand = Color(0xFFF0F4F3);

  // NEW: fixed height for every list row
  static const double kRowHeight = 100;

  void _clearSelection() => setState(_selected.clear);

  void _toggleSelection(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _startSelection(String id) {
    if (_selectionMode) {
      _toggleSelection(id);
    } else {
      setState(() => _selected.add(id));
    }
  }

  void _selectAllVisible() {
    if (_latest.isEmpty) return;
    setState(() {
      if (_selected.length == _latest.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_latest.map((n) => n.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final count = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete notes?'),
        content: Text(
          'You are about to delete $count note${count == 1 ? '' : 's'}. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (!ok) return;

    final ids = _selected.toList();
    _clearSelection();
    for (final id in ids) {
      try {
        await _svc.delete(id);
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted $count note${count == 1 ? '' : 's'}')),
    );
  }

  // Intercept Android back: exit selection mode first
  Future<bool> _onWillPop() async {
    if (_selectionMode) {
      _clearSelection();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF7F8FB);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: bg,
        floatingActionButton: _selectionMode
            ? null
            : FloatingActionButton.extended(
          backgroundColor: _brand,
          foregroundColor: _onBrand,
          icon: const Icon(Icons.add),
          label: const Text('New note'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NoteEditorPage()),
          ),
        ),
        body: StreamBuilder<List<NoteModel>>(
          initialData: _cache,
          stream: _svc.streamNotes(newestFirst: _newestFirst),
          builder: (context, snap) {
            // ---------- OLD HEADER (restored) ----------
            Widget headerBox(int noteCount) {
              final topInset = MediaQuery.of(context).padding.top; // status-bar height
              final headerBg = Colors.grey[50]!;
              return ColoredBox(
                color: headerBg, // paint behind status bar
                child: Padding(
                  padding: EdgeInsets.only(top: topInset),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: headerBg,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (_selectionMode) ...[
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _clearSelection,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Cancel selection',
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_selected.length} selected',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _selectAllVisible,
                            child: Text(
                              _selected.length == _latest.length && _latest.isNotEmpty
                                  ? 'Clear'
                                  : 'Select all',
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                            onPressed: _deleteSelected,
                            tooltip: 'Delete selected',
                          ),
                        ] else ...[
                          const Icon(Icons.sticky_note_2, color: _brand, size: 24),
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
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }
            // ------------------------------------------

            // ---- Error first
            if (snap.hasError) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: headerBox(_cache?.length ?? 0)),
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Error loading notes')),
                  ),
                ],
              );
            }

            // ---- Initial loading (no data yet)
            if (!snap.hasData) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: headerBox(0)),
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }

            final notes = snap.data!;
            _cache = notes;
            _latest = notes;

            // ---- Empty state
            if (notes.isEmpty) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: headerBox(0)),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sticky_note_2_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No notes yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap “New note” to add your first one.',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // ---- Data
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: headerBox(notes.length)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, i) {
                        final n = notes[i];
                        final first = n.imagesB64.isNotEmpty ? n.imagesB64.first : null;
                        final selected = _selected.contains(n.id);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Stack(
                            children: [
                              // FIXED-HEIGHT ROW
                              SizedBox(
                                height: kRowHeight,
                                child: Card(
                                  elevation: 0.8,
                                  shadowColor: Colors.black12,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: selected ? _brand.withOpacity(0.6) : Colors.grey.shade200,
                                    ),
                                  ),
                                  color: selected ? _brand.withOpacity(0.035) : Colors.white,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onLongPress: () => _startSelection(n.id),
                                    onTap: () {
                                      if (_selectionMode) {
                                        _toggleSelection(n.id);
                                      } else {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => NoteViewPage(noteId: n.id)),
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // leading thumbnail (fixed size)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: first == null
                                                ? SizedBox(width: 56, height: 56, child: placeholderThumb())
                                                : smartThumb(first, w: 56, h: 56, fit: BoxFit.cover),
                                          ),
                                          const SizedBox(width: 12),

                                          // TEXT BLOCK (replaces the mistaken title:/subtitle: usage)
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Title line
                                                Text(
                                                  n.title.isEmpty ? '(Untitled)' : n.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                                const SizedBox(height: 6),

                                                // Second line: preview + footer in one vertical group
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        n.text.isEmpty ? '(No text)' : n.text,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(height: 1.2),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),

                                                Row(
                                                  children: [
                                                    if (n.jobId.isNotEmpty)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(8),
                                                          color: Colors.indigo.withOpacity(0.07),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: const [
                                                            Icon(Icons.confirmation_number_outlined, size: 14, color: Colors.indigo),
                                                            SizedBox(width: 4),
                                                          ],
                                                        ),
                                                      ),
                                                    if (n.jobId.isNotEmpty)
                                                      Text(
                                                        n.jobId,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.indigo,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    const Spacer(),
                                                    Text(
                                                      _fmt(n.createdAt),
                                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // selection check overlay (kept)
                              if (_selectionMode)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: AnimatedScale(
                                    scale: selected ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 140),
                                    child: Container(
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                      child: const Icon(Icons.check_circle, color: _brand),
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
      ),
    );
  }
}
