import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/notes_service.dart';
import '../services/note_model.dart';
import '../ui/image_utils.dart';
import 'note_editor_page.dart';

class NoteViewPage extends StatelessWidget {
  final String noteId;
  const NoteViewPage({super.key, required this.noteId});

  String _fmt(DateTime? d) =>
      d == null ? '—' : DateFormat('d MMM yyyy · HH:mm').format(d);

  Color get _brand => const Color(0xFF2B384C);

  @override
  Widget build(BuildContext context) {
    final svc = NotesService();

    return StreamBuilder<NoteModel?>(
      stream: svc.watchNote(noteId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Error: ${snap.error}')),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final n = snap.data;
        if (n == null) {
          return const Scaffold(
            body: Center(child: Text('This note was deleted.')),
          );
        }

        final imgCount = n.imagesB64.length;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // ===== Header =====
              SliverPadding(
                // padding: const EdgeInsets.all(8.0),
                padding: const EdgeInsets.only(top: 8), // <- small gap above the header
                sliver: SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                  titleSpacing: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Row(
                    children: [
                      const SizedBox(width: 8),
                      Icon(Icons.description, color: _brand, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              n.title.isEmpty ? 'Note' : n.title,        // ← NEW
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              n.jobId.isEmpty ? 'No job selected' : n.jobId,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NoteEditorPage(noteId: n.id),
                          ),
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'copyText') {
                          await Clipboard.setData(ClipboardData(text: n.text));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied note text')),
                            );
                          }
                        } else if (v == 'delete') {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete note?'),
                              content: const Text(
                                  'This action cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                  ),
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ) ??
                              false;
                          if (ok) {
                            svc.delete(n.id);
                            if (context.mounted) Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Note deleted')),
                            );
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'copyText',
                          child: Text('Copy text'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),

              // ===== Body =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Meta chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip(
                            icon: Icons.work_outline,
                            label:
                            (n.jobId.isEmpty ? 'No job' : n.jobId),
                          ),
                          _chip(
                            icon: Icons.schedule,
                            label: _fmt(n.createdAt),
                          ),
                          _chip(
                            icon: Icons.photo_library_outlined,
                            label:
                            '$imgCount image${imgCount == 1 ? '' : 's'}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Images
                      if (n.imagesB64.isEmpty)
                        Container(
                          height: 220,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 100,
                              child: placeholderThumb(),
                            ),
                          ),
                        )
                      else
                        _ImagesCarouselSection(
                          images: n.imagesB64,
                          brand: _brand,
                        ),

                      const SizedBox(height: 16),

                      // Text card
                      Card(
                        elevation: 0,
                        color: Colors.grey[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.notes, color: _brand),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  n.text.isEmpty ? '(No text)' : n.text,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copy',
                                onPressed: () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: n.text));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content: Text('Copied note text'),
                                    ));
                                  }
                                },
                                icon: const Icon(Icons.copy_all_rounded),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipeable image carousel + page indicator + fullscreen viewer.
class _ImagesCarouselSection extends StatefulWidget {
  final List<String> images;
  final Color brand;
  const _ImagesCarouselSection({
    required this.images,
    required this.brand,
  });

  @override
  State<_ImagesCarouselSection> createState() => _ImagesCarouselSectionState();
}

class _ImagesCarouselSectionState extends State<_ImagesCarouselSection> {
  late final PageController _pc;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: .92);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _pc,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _showFullScreen(context, images, i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: smartThumb(
                    images[i],
                    w: double.infinity,
                    h: 230,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(images.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 8,
              width: active ? 18 : 8,
              decoration: BoxDecoration(
                color: active ? widget.brand : Colors.grey[300],
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }

  void _showFullScreen(BuildContext context, List<String> images, int start) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.9),
      builder: (_) {
        final controller = PageController(initialPage: start);
        int idx = start;
        return StatefulBuilder(
          builder: (context, setState) => GestureDetector(
            // tap to dismiss
            onTap: () => Navigator.pop(context),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                PageView.builder(
                  controller: controller,
                  onPageChanged: (i) => setState(() => idx = i),
                  itemCount: images.length,
                  itemBuilder: (_, i) => Center(
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: smartThumb(
                        images[i],
                        w: MediaQuery.of(context).size.width,
                        h: MediaQuery.of(context).size.height,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                // page indicator
                Positioned(
                  bottom: 28,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${idx + 1}/${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
