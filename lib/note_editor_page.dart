/*
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/notes_service.dart';
import '../services/note_model.dart';

class NoteEditorPage extends StatefulWidget {
  final String? noteId; // null → create
  final String? preselectedJobId;
  const NoteEditorPage({super.key, this.noteId, this.preselectedJobId});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _svc = NotesService();
  final _jobId = TextEditingController();
  final _text = TextEditingController();
  final _picker = ImagePicker();

  List<String> _remote = []; // existing/download URLs
  List<File> _local = [];    // newly picked files
  bool _loading = false;

  // Brand colors (match your app)
  static const _brand = Color(0xFF2B384C);
  static const _onBrand = Color(0xFFF0F4F3);

  String? _selectedJobId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.noteId != null) {
      final existing = await _svc.getNote(widget.noteId!);
      if (existing != null) {
        _jobId.text = existing.jobId;
        _selectedJobId = existing.jobId.isEmpty ? null : existing.jobId;
        _text.text = existing.text;
        _remote = List.of(existing.images);
        setState(() {});
      }
    } else {
      _jobId.text = widget.preselectedJobId ?? '';
      _selectedJobId = widget.preselectedJobId;
      setState(() {});
    }
  }

  // --- Firestore jobs stream → dropdown options
  Stream<List<_JobOption>> _jobOptionsStream() {
    return FirebaseFirestore.instance.collection('jobs').snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        final id = (data['id'] as String?) ?? d.id;
        final customer = (data['customerName'] as String?) ?? '';
        final status = (data['status'] as String?) ?? '';
        final label = [
          id,
          if (customer.isNotEmpty) '• $customer',
          if (status.isNotEmpty) '• $status',
        ].join(' ');
        return _JobOption(id: id, label: label);
      }).toList()
        ..sort((a, b) => a.id.compareTo(b.id)); // simple sort by id
    });
  }

  Future<void> _pickGallery() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() => _local.addAll(files.map((x) => File(x.path))));
  }

  Future<void> _pickCamera() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x != null) setState(() => _local.add(File(x.path)));
  }

  Future<void> _save() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final id = widget.noteId ?? '';
      final noteId = id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : id;

      // upload newly picked images
      // final uploads = <String>[];
      // for (final f in _local) {
      //   final url = await _svc.uploadImage(noteId, f);
      //   uploads.add(url);
      // }
      //
      // final model = NoteModel(
      //   id: noteId,
      //   userId: FirebaseAuth.instance.currentUser!.uid, // <— add this
      //   jobId: _jobId.text.trim(),
      //   text: _text.text.trim(),
      //   images: [..._remote, ...uploads],
      //   createdAt: DateTime.now(),
      // );
      // await _svc.upsert(model);

      // final uploads = <String>[];
      // final storagePaths = <String>[];
      // for (final f in _local) {
      //   final res = await _svc.uploadImage(noteId, f);
      //   uploads.add(res.url);
      //   storagePaths.add(res.path);
      // }
      //
      // final model = NoteModel(
      //   id: noteId,
      //   userId: FirebaseAuth.instance.currentUser!.uid,
      //   jobId: _jobId.text.trim(),
      //   text: _text.text.trim(),
      //   images: [..._remote, ...uploads],
      //   imagePaths: storagePaths, // new
      //   // createdAt is server-set on create
      // );
      // await _svc.upsert(model);

      final b64list = <String>[];
      for (final f in _local) {
        final dataUri = await _svc.fileToDataUri(f); // compress & encode
        b64list.add(dataUri);
      }

      final model = NoteModel(
        id: noteId,
        userId: FirebaseAuth.instance.currentUser!.uid,
        jobId: _jobId.text.trim(),
        text: _text.text.trim(),
        images: _remote,          // keep if you had old URL-based images
        imagesB64: b64list,       // new base64 images
        // createdAt is set on create (serverTimestamp) in upsert
      );
      await _svc.upsert(model);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _imageCount => _remote.length + _local.length;

  @override
  void dispose() {
    _jobId.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: CustomScrollView(
        slivers: [
          _headerSliver(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Job dropdown
                  StreamBuilder<List<_JobOption>>(
                    stream: _jobOptionsStream(),
                    builder: (context, snap) {
                      final options = snap.data ?? const <_JobOption>[];

                      // If we have a preselected id that's not present (e.g. archived job),
                      // inject a temporary option so the UI still displays it.
                      final hasSelected =
                          _selectedJobId != null && options.any((o) => o.id == _selectedJobId);
                      final displayOptions = hasSelected
                          ? options
                          : (_selectedJobId == null
                          ? options
                          : [
                        _JobOption(
                            id: _selectedJobId!,
                            label: '${_selectedJobId!} • (archived)'),
                        ...options
                      ]);

                      return DropdownButtonFormField<String>(
                        value: _selectedJobId,
                        isExpanded: true,
                        items: displayOptions
                            .map((o) => DropdownMenuItem(
                          value: o.id,
                          child: Text(o.label, overflow: TextOverflow.ellipsis),
                        ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedJobId = val;
                            _jobId.text = val ?? '';
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Job',
                          border: OutlineInputBorder(),
                        ),
                        hint: snap.connectionState == ConnectionState.waiting
                            ? const Text('Loading jobs…')
                            : const Text('Select a job'),
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
                    remote: _remote,
                    local: _local,
                    onRemoveRemote: (i) => setState(() => _remote.removeAt(i)),
                    onRemoveLocal: (i) => setState(() => _local.removeAt(i)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _text,
                    maxLines: 8,
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
                      style: FilledButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: _onBrand,
                      ),
                      onPressed: _loading ? null : _save,
                      icon: _loading
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
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
    );
  }

  /// Branded SliverAppBar with rounded bottom and an image-count stat line.
  SliverAppBar _headerSliver() {
    final isEdit = widget.noteId != null;
    final title = isEdit ? 'Edit note' : 'Add note';

    return SliverAppBar(
      pinned: true,
      expandedHeight: 132,
      backgroundColor: _brand,
      foregroundColor: _onBrand,
      elevation: 1,
      shape: const ContinuousRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),

      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),

      actions: [
        IconButton(
          tooltip: 'Save',
          onPressed: _loading ? null : _save,
          icon: _loading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.save),
        ),
        const SizedBox(width: 4),
      ],

      flexibleSpace: const FlexibleSpaceBar(collapseMode: CollapseMode.pin),

      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(34),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              '$_imageCount image${_imageCount == 1 ? '' : 's'} attached',
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

class _JobOption {
  final String id;
  final String label;
  const _JobOption({required this.id, required this.label});
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
        child: Image.network(remote[i], fit: BoxFit.cover),
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
*/

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
    return FirebaseFirestore.instance
        .collection('jobs')
        .orderBy('id')
        .snapshots()
        .map((s) => s.docs.map((d) {
      final m = d.data();
      final id = (m['id'] as String?) ?? d.id;
      final c = (m['customerName'] as String?) ?? '';
      final st = (m['status'] as String?) ?? '';
      return _Job(id, [id, if (c.isNotEmpty) '• $c', if (st.isNotEmpty) '• $st'].join(' '));
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
    if (!_formKey.currentState!.validate()) {            // ← add
      // show a quick nudge if you want
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Job.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final id = widget.noteId ?? DateTime.now().millisecondsSinceEpoch.toString();

      // convert local files → Base64 data URIs
      final newB64 = <String>[];
      for (final f in _localFiles) {
        final dataUri = await _svc.fileToDataUri(f);
        newB64.add(dataUri);
      }

      final model = NoteModel(
        id: id,
        userId: FirebaseAuth.instance.currentUser!.uid,
        jobId: _selectedJobId ?? '',
        title: _title.text.trim(),
        text: _text.text.trim(),
        imagesB64: [..._remoteB64, ...newB64],
      );

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
            // SliverAppBar(
            //   pinned: true,
            //   expandedHeight: 132,
            //   backgroundColor: _brand,
            //   foregroundColor: _onBrand,
            //   title: Text(isEdit ? 'Edit note' : 'Add note',
            //       style: const TextStyle(fontWeight: FontWeight.w700)),
            //   actions: [
            //     IconButton(
            //       tooltip: 'Save',
            //       onPressed: _saving ? null : _save,
            //       icon: _saving
            //           ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            //           : const Icon(Icons.save),
            //     ),
            //     const SizedBox(width: 4),
            //   ],
            //   flexibleSpace: const FlexibleSpaceBar(collapseMode: CollapseMode.pin),
            //   bottom: PreferredSize(
            //     preferredSize: const Size.fromHeight(34),
            //     child: Align(
            //       alignment: Alignment.centerLeft,
            //       child: Padding(
            //         padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            //         child: Text('$_imageCount image${_imageCount == 1 ? '' : 's'} attached',
            //           style: const TextStyle(color: _onBrand, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: .3),
            //         ),
            //       ),
            //     ),
            //   ),
            // ),
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
                          items: jobs.map((j) =>
                              DropdownMenuItem(value: j.id, child: Text(j.label))
                          ).toList(),
                          onChanged: (v) => setState(() => _selectedJobId = v),
                          decoration: const InputDecoration(labelText: 'Job', border: OutlineInputBorder()),
                          hint: snap.connectionState == ConnectionState.waiting
                              ? const Text('Loading jobs…')
                              : const Text('Select a job'),
                          autovalidateMode: AutovalidateMode.onUserInteraction,     // ← add
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

                    // Images preview
                    // SizedBox(
                    //   height: 120,
                    //   child: ListView.separated(
                    //     scrollDirection: Axis.horizontal,
                    //     itemCount: _remoteB64.length + _localFiles.length,
                    //     separatorBuilder: (_, __) => const SizedBox(width: 8),
                    //     itemBuilder: (_, i) {
                    //       final isRemote = i < _remoteB64.length;
                    //       final child = isRemote
                    //           ? dataUriThumb(_remoteB64[i], w: 180, h: 120, fit: BoxFit.cover)
                    //           : Image.file(_localFiles[i - _remoteB64.length], width: 180, height: 120, fit: BoxFit.cover);
                    //
                    //       return Stack(children: [
                    //         ClipRRect(
                    //           borderRadius: BorderRadius.circular(10),
                    //           child: Container(width: 180, height: 120, color: Colors.grey.shade200, child: child),
                    //         ),
                    //         Positioned(
                    //           top: 6, right: 6,
                    //           child: GestureDetector(
                    //             onTap: () => setState(() => isRemote
                    //                 ? _remoteB64.removeAt(i)
                    //                 : _localFiles.removeAt(i - _remoteB64.length)),
                    //             child: Container(
                    //               decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    //               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    //               child: const Icon(Icons.close, color: Colors.white, size: 16),
                    //             ),
                    //           ),
                    //         ),
                    //       ]);
                    //     },
                    //   ),
                    // ),
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