import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notes_service.dart';
import '../services/note_model.dart';
import '../ui/image_utils.dart';
import 'note_editor_page.dart';

class NoteViewPage extends StatelessWidget {
  final String noteId;
  const NoteViewPage({super.key, required this.noteId});

  String _fmt(DateTime? d) =>
      d == null ? '—' : DateFormat('d MMM yyyy HH:mm').format(d!);

  @override
  Widget build(BuildContext context) {
    final svc = NotesService();

    return StreamBuilder<NoteModel?>(
      stream: svc.watchNote(noteId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(appBar: AppBar(), body: Center(child: Text('Error: ${snap.error}')));
        }
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final n = snap.data;
        if (n == null) {
          return const Scaffold(body: Center(child: Text('This note was deleted.')));
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // === Sliver header (inline, pinned) ===
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.grey[50],
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
                    const Icon(Icons.description, color: Colors.indigo, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Note',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            n.jobId.isEmpty ? 'No job selected' : n.jobId,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                        MaterialPageRoute(builder: (_) => NoteEditorPage(noteId: n.id)),
                      );
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete note?'),
                            content: const Text('This cannot be undone.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete')),
                            ],
                          ),
                        ) ??
                            false;
                        if (ok) {
                          await svc.delete(n.id);
                          if (context.mounted) Navigator.pop(context);
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),

              // === Page body ===
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_fmt(n.createdAt), style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),

                      // images
                      if (n.imagesB64.isEmpty)
                        Container(
                          height: 220,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(child: SizedBox(width: 100, child: placeholderThumb())),
                        )
                      else
                        SizedBox(
                          height: 220,
                          child: PageView.builder(
                            controller: PageController(viewportFraction: .92),
                            itemCount: n.imagesB64.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: smartThumb(
                                  n.imagesB64[i],
                                  w: double.infinity,
                                  h: 220,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),
                      Text(
                        n.text.isEmpty ? '(No text)' : n.text,
                        style: const TextStyle(fontSize: 16, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        // return Scaffold(
        //   appBar: AppBar(
        //     title: const Text('Note'),
        //     actions: [
        //       IconButton(
        //         tooltip: 'Edit',
        //         icon: const Icon(Icons.edit),
        //         onPressed: () async {
        //           await Navigator.of(context).push(
        //             MaterialPageRoute(builder: (_) => NoteEditorPage(noteId: n.id)),
        //           );
        //         },
        //       ),
        //       PopupMenuButton<String>(
        //         onSelected: (v) async {
        //           if (v == 'delete') {
        //             final ok = await showDialog<bool>(
        //               context: context,
        //               builder: (_) => AlertDialog(
        //                 title: const Text('Delete note?'),
        //                 content: const Text('This cannot be undone.'),
        //                 actions: [
        //                   TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        //                   FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        //                 ],
        //               ),
        //             ) ??
        //                 false;
        //             if (ok) {
        //               await svc.delete(n.id);
        //               // go back to the list after delete
        //               // ignore if already popped
        //               if (context.mounted) Navigator.pop(context);
        //             }
        //           }
        //         },
        //         itemBuilder: (_) => const [
        //           PopupMenuItem(value: 'delete', child: Text('Delete')),
        //         ],
        //       ),
        //     ],
        //   ),
        //   body: ListView(
        //     padding: const EdgeInsets.all(16),
        //     children: [
        //       Text(
        //         n.jobId.isEmpty ? '—' : n.jobId,
        //         style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        //       ),
        //       const SizedBox(height: 4),
        //       Text(_fmt(n.createdAt), style: const TextStyle(color: Colors.grey)),
        //       const SizedBox(height: 12),
        //
        //       // images
        //       if (n.imagesB64.isEmpty)
        //         Container(
        //           height: 220,
        //           decoration: BoxDecoration(
        //             color: Colors.grey.shade200,
        //             borderRadius: BorderRadius.circular(10),
        //           ),
        //           child: Center(child: SizedBox(width: 100, child: placeholderThumb())),
        //         )
        //       else
        //         SizedBox(
        //           height: 220,
        //           child: PageView.builder(
        //             controller: PageController(viewportFraction: .92),
        //             itemCount: n.imagesB64.length,
        //             itemBuilder: (_, i) => Padding(
        //               padding: const EdgeInsets.only(right: 8),
        //               child: ClipRRect(
        //                 borderRadius: BorderRadius.circular(10),
        //                 // child: dataUriThumb(
        //                 //   n.imagesB64[i],
        //                 //   w: double.infinity,
        //                 //   h: 220,
        //                 //   fit: BoxFit.cover,
        //                 // ),
        //                 child: smartThumb(
        //                   n.imagesB64[i],
        //                   w: double.infinity,
        //                   h: 220,
        //                   fit: BoxFit.cover,
        //                 ),
        //               ),
        //             ),
        //           ),
        //         ),
        //
        //       const SizedBox(height: 16),
        //       Text(
        //         n.text.isEmpty ? '(No text)' : n.text,
        //         style: const TextStyle(fontSize: 16, height: 1.4),
        //       ),
        //     ],
        //   ),
        // );
      },
    );
  }
}