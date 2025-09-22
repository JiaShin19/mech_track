import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/notes_service.dart';
import '../services/note_model.dart';
import '../ui/image_utils.dart';

class NoteEditorPage extends StatefulWidget {
  final String? noteId;
  const NoteEditorPage({super.key, this.noteId});
  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _svc = NotesService();
  final _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _text = TextEditingController();
  String? _selectedJobId;

  final List<String> _remoteB64 = []; // existing data URIs (when editing)
  final List<File> _localFiles = [];  // newly picked files
  bool _saving = false;

  static const _brand = Color(0xFF2B384C);
  static const _onBrand = Color(0xFFF0F4F3);

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    if (widget.noteId == null) return;
    final n = await _svc.getNote(widget.noteId!);
    if (n == null) return;
    setState(() {
      _selectedJobId = n.jobId.isEmpty ? null : n.jobId;
      _title.text = n.title;
      _text.text = n.text;
      _remoteB64.clear();
      _remoteB64.addAll(n.imagesB64);
    });
  }

  // Jobs dropdown (from /jobs)
  Stream<List<_Job>> _jobOptions() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('jobs')
        .where('assignedToEmail', isEqualTo: user.email)
        .orderBy('id')
        .snapshots()
        .map((s) => s.docs.map((d) {
      final m = d.data();
      final id = (m['id'] as String?) ?? d.id;
      final c = (m['customerName'] as String?) ?? '';
      final st = (m['status'] as String?) ?? '';
      return _Job(
        id,
        [id, if (c.isNotEmpty) '• $c', if (st.isNotEmpty) '• $st'].join(' '),
      );
    }).toList());
  }

  Future<void> _pickGallery() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() => _localFiles.addAll(files.map((x) => File(x.path))));
  }

  Future<void> _pickCamera() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x != null) setState(() => _localFiles.add(File(x.path)));
  }

  Future<void> _save() async {
    if (_saving) return;

    // validate required fields
    if (_selectedJobId == null || _selectedJobId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Job.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final id = widget.noteId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final currentUser = FirebaseAuth.instance.currentUser;
      final userEmail = currentUser?.email?.toLowerCase();

      final jobDoc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(_selectedJobId)
          .get();

      if (!jobDoc.exists) {
        throw 'Selected job not found in Firestore';
      }

      final jobData = jobDoc.data()!;
      final jobAssignedEmail = (jobData['assignedToEmail'] as String?)?.toLowerCase();

      // ✅ Check if job belongs to this user
      if (jobAssignedEmail != userEmail) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are not assigned to this job.')),
        );
        setState(() => _saving = false);
        return;
      }

      // convert local files → Base64 data URIs
      final newB64 = <String>[];
      for (final f in _localFiles) {
        final dataUri = await _svc.fileToDataUri(f);
        newB64.add(dataUri);
      }

      final model = NoteModel(
        id: id,
        userId: currentUser!.uid,
        jobId: _selectedJobId!,
        title: _title.text.trim(),
        text: _text.text.trim(),
        imagesB64: [..._remoteB64, ...newB64],
      );

      print(model.toMap());
      await _svc.upsert(model);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int get _imageCount => _remoteB64.length + _localFiles.length;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.noteId != null;

    return Scaffold(
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.grey[50],
              foregroundColor: Colors.black87,
              // thin bottom border like service_history.dart
              shape: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              // build the whole header body yourself (icon + title + subtitle)
              title: Row(
                children: [
                  const SizedBox(width: 8),
                  const Icon(Icons.note_alt, color: Color(0xFF2B384C), size: 22),
                  const SizedBox(width: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.noteId == null ? 'Add note' : 'Edit note',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_imageCount image${_imageCount == 1 ? '' : 's'} attached',
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
                  tooltip: 'Save',
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                ),
                const SizedBox(width: 4),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Job dropdown
                    StreamBuilder<List<_Job>>(
                      stream: _jobOptions(),
                      builder: (context, snap) {
                        final jobs = snap.data ?? const <_Job>[];
                        final value = jobs.any((j) => j.id == _selectedJobId) ? _selectedJobId : null;

                        return DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: value,
                          items: jobs.map((j) {
                            final parts = j.label.split('•');
                            final jobId = parts.isNotEmpty ? parts[0].trim() : j.id;
                            final customer = parts.length > 1 ? parts[1].trim() : "";
                            final status = parts.length > 2 ? parts[2].trim() : "";

                            Color statusColor;
                            switch (status.toLowerCase()) {
                              case "completed":
                                statusColor = Colors.green.shade100;
                                break;
                              case "in progress":
                                statusColor = Colors.orange.shade100;
                                break;
                              default:
                                statusColor = Colors.blue.shade100;
                            }

                            return DropdownMenuItem(
                              value: j.id,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          jobId,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        if (customer.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              customer,
                                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (status.isNotEmpty)
                                    Chip(
                                      label: Text(status, style: const TextStyle(fontSize: 11)),
                                      backgroundColor: statusColor,
                                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      padding: EdgeInsets.zero,
                                      labelPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedJobId = v),
                          decoration: const InputDecoration(
                            labelText: 'Job',
                            border: OutlineInputBorder(),
                          ),
                          menuMaxHeight: 300,
                          hint: snap.connectionState == ConnectionState.waiting
                              ? const Text('Loading jobs…')
                              : const Text('Select a job'),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Job is required';
                            return null;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      ElevatedButton.icon(
                        onPressed: _pickGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _pickCamera,
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Camera'),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _ImagesCarousel(
                      remote: _remoteB64,
                      local: _localFiles,
                      onRemoveRemote: (i) => setState(() => _remoteB64.removeAt(i)),
                      onRemoveLocal: (i) => setState(() => _localFiles.removeAt(i)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _title,
                      textInputAction: TextInputAction.next,
                      maxLength: 80, // optional
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Enter a short title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _text, maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _brand, foregroundColor: _onBrand),
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      )
    );
  }
}

class _Job {
  final String id;
  final String label;
  _Job(this.id, this.label);
}

class _ImagesCarousel extends StatelessWidget {
  final List<String> remote;
  final List<File> local;
  final void Function(int) onRemoveRemote;
  final void Function(int) onRemoveLocal;
  const _ImagesCarousel({
    required this.remote,
    required this.local,
    required this.onRemoveRemote,
    required this.onRemoveLocal,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (int i = 0; i < remote.length; i++) {
      children.add(_Thumb(
        // child: Image.network(remote[i], fit: BoxFit.cover),
        child: smartThumb(remote[i], w: 180, h: 120, fit: BoxFit.cover),
        onRemove: () => onRemoveRemote(i),
      ));
    }
    for (int i = 0; i < local.length; i++) {
      children.add(_Thumb(
        child: Image.file(local[i], fit: BoxFit.cover),
        onRemove: () => onRemoveLocal(i),
      ));
    }

    if (children.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No images yet'),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  const _Thumb({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 180,
            height: 120,
            color: Colors.grey.shade200,
            child: child,
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}