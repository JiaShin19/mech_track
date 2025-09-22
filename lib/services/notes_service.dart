import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;

import 'note_model.dart';

class NotesService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not authenticated');
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>> get _notes =>
      _db.collection('notes');

  /// All notes for current user
  Stream<List<NoteModel>> streamNotes({bool newestFirst = true}) {
    return _notes
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: newestFirst)
        .snapshots()
        .map((q) {
      final notes = q.docs.map(NoteModel.fromDoc).toList();

      final box = Hive.box('notesCache');
      box.put('notes', notes.map((n) => n.toMap()).toList());

      return notes;
    });
  }

  Future<List<NoteModel>> loadCachedNotes() async {
    final box = Hive.box('notesCache');
    final cached = box.get('notes', defaultValue: []);
    return (cached as List)
        .map((m) => NoteModel.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> cacheNote(NoteModel m) async {
    final box = Hive.box('notesCache');
    final cached = box.get('notes', defaultValue: []);
    final list = List<Map<String, dynamic>>.from(cached);

    // replace if already exists
    list.removeWhere((n) => n['id'] == m.id);
    list.add(m.toMap());

    await box.put('notes', list);
  }

  Future<void> cacheDelete(List<String> ids) async {
    final box = Hive.box('notesCache');
    final cached = box.get('notes', defaultValue: []);
    final list = List<Map<String, dynamic>>.from(cached);

    list.removeWhere((n) => ids.contains(n['id']));
    await box.put('notes', list);
  }

  // Filtered notes (jobId / date range / hasImages), only for current user
  Stream<List<NoteModel>> streamNotesFiltered({
    // required bool newestFirst,
    bool newestFirst = true,
    String? jobId,
    DateTime? start,
    DateTime? end,
    bool? hasImages,
  }) {
    Query<Map<String, dynamic>> q =
    _notes.where('userId', isEqualTo: _uid);

    if (jobId != null && jobId.trim().isNotEmpty) {
      q = q.where('jobId', isEqualTo: jobId.trim());
    }
    if (start != null) {
      q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    }
    if (end != null) {
      q = q.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));
    }
    if (hasImages != null) {
      q = q.where('hasImages', isEqualTo: hasImages);
    }

    q = q.orderBy('createdAt', descending: newestFirst);

    return q.snapshots().map((s) => s.docs.map(NoteModel.fromDoc).toList());
  }

  Stream<NoteModel?> watchNote(String id) {
    return _notes.doc(id).snapshots().map(
          (d) => d.exists ? NoteModel.fromDoc(d) : null,
    );
  }

  Future<NoteModel?> getNote(String id) async {
    final doc = await _notes.doc(id).get();
    if (!doc.exists) return null;
    return NoteModel.fromDoc(doc);
  }

  /// Upsert: works offline (cached immediately, Firestore syncs later)
  Future<void> upsert(NoteModel m) async {
    final ref = _notes.doc(m.id.isEmpty ? _notes.doc().id : m.id);

    final data = m.toMap()..['id'] = ref.id;
    data['userId'] = _uid;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['hasImages'] =
        ((data['images'] as List?)?.isNotEmpty ?? false) ||
            ((data['imagesB64'] as List?)?.isNotEmpty ?? false);

    // save locally first
    await cacheNote(m);

    try {
      await ref.set(data, SetOptions(merge: true));
    } catch (e) {
      // offline: Firestore queues and retries later
      print("Firestore offline, note cached only: $e");
    }
  }

  // Future<void> delete(String id) async => _notes.doc(id).delete();
  Future<void> delete(String id) async {
    // remove locally
    await cacheDelete([id]);
    try {
      await _notes.doc(id).delete();
    } catch (e) {
      print("Firestore offline, delete cached only: $e");
    }
  }

  /// Compress to ~900px wide JPEG, return data URI string.
  Future<String> fileToDataUri(File file,
      {int maxWidth = 900, int quality = 75}) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Unsupported image: ${file.path}');
    }
    final resized =
        decoded.width > maxWidth ? img.copyResize(decoded, width: maxWidth) : decoded;
    final jpg = img.encodeJpg(resized, quality: quality);
    final b64 = base64Encode(jpg);
    return 'data:image/jpeg;base64,$b64';
  }
}