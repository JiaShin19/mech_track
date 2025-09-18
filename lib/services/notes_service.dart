// import 'dart:io';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:uuid/uuid.dart';
//
// class NoteModel {
//   String id;
//   String jobId;
//   String text;
//   List<String> images; // download URLs
//   DateTime createdAt;
//
//   NoteModel({
//     required this.id,
//     required this.jobId,
//     required this.text,
//     required this.images,
//     required this.createdAt,
//   });
//
//   Map<String, dynamic> toMap() => {
//     'jobId': jobId,
//     'text': text,
//     'images': images,
//     'createdAt': Timestamp.fromDate(createdAt),
//   };
//
//   static NoteModel fromDoc(DocumentSnapshot doc) {
//     final d = doc.data() as Map<String, dynamic>;
//     return NoteModel(
//       id: doc.id,
//       jobId: (d['jobId'] ?? '') as String,
//       text: (d['text'] ?? '') as String,
//       images: List<String>.from((d['images'] ?? []) as List),
//       createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
//     );
//   }
// }
//
// class NotesService {
//   final _auth = FirebaseAuth.instance;
//   final _db = FirebaseFirestore.instance;
//   final _storage = FirebaseStorage.instance;
//
//   String get _uid => _auth.currentUser!.uid;
//   CollectionReference<Map<String, dynamic>> get _col => _db.collection('users').doc(_uid).collection('notes');
//
//   Stream<List<NoteModel>> streamNotes({bool newestFirst = true}) {
//     return _col.orderBy('createdAt', descending: newestFirst).snapshots().map(
//           (s) => s.docs.map(NoteModel.fromDoc).toList(),
//     );
//   }
//
//   Future<NoteModel?> getNote(String id) async {
//     final doc = await _col.doc(id).get();
//     if (!doc.exists) return null;
//     return NoteModel.fromDoc(doc);
//   }
//
//   Future<String> upsert(NoteModel note) async {
//     final ref = _col.doc(note.id.isEmpty ? null : note.id);
//     final id = ref.id;
//     await _col.doc(id).set(note.toMap(), SetOptions(merge: true));
//     return id;
//   }
//
//   Future<void> delete(String id) async {
//   // Optional: delete images from storage as well
//     final doc = await _col.doc(id).get();
//     final images = List<String>.from((doc.data()?['images'] ?? []) as List);
//     for (final url in images) {
//       try { await _storage.refFromURL(url).delete(); } catch (_) {}
//     }
//     await _col.doc(id).delete();
//   }
//
//   Future<String> uploadImage(String noteId, File file) async {
//     final path = 'users/$_uid/notes/$noteId/${const Uuid().v4()}.jpg';
//     final ref = _storage.ref(path);
//     await ref.putFile(file);
//     return ref.getDownloadURL();
//   }
// }

/*
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:mech_track/services/note_model.dart';

class NotesService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not authenticated');
    return u.uid;
  }

  Stream<List<NoteModel>> streamNotes({bool newestFirst = true}) {
    return _db
        .collection('notes')
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: newestFirst)
        .snapshots()
        .map((q) => q.docs.map((d) => NoteModel.fromMap(d.data())).toList());
  }

  Future<NoteModel?> getNote(String id) async {
    final doc = await _db.collection('notes').doc(id).get();
    if (!doc.exists) return null;
    return NoteModel.fromMap(doc.data()!);
  }

  /// Use serverTimestamp on create; keep existing createdAt on updates.
  Future<void> upsert(NoteModel m) async {
    final ref = _db.collection('notes').doc(m.id);
    final snap = await ref.get();
    final data = m.toMap();

    if (!snap.exists) {
      data['createdAt'] = FieldValue.serverTimestamp(); // set by server
    }
    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> delete(String id, {List<String> storagePaths = const []}) async {
    await _db.collection('notes').doc(id).delete();
    // Optional: also delete images by storage path (if you store them)
    for (final p in storagePaths) {
      try { await _storage.ref(p).delete(); } catch (_) {}
    }
  }

  /// More robust upload: checks file and uses putData
  Future<({String url, String path})> uploadImage(String noteId, File file) async {
    if (!file.existsSync()) {
      throw StateError('Image not found: ${file.path}');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('Image is empty: ${file.path}');
    }

    final imageId = const Uuid().v4();
    final path = 'notes/$_uid/$noteId/$imageId.jpg';
    final ref = _storage.ref(path);

    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();

    return (url: url, path: path);
  }
}
*/

/*
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:mech_track/services/note_model.dart';
import 'package:image/image.dart' as img; // add `image: ^4.1.7` to pubspec for resizing/compression

class NotesService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not authenticated');
    return u.uid;
  }

  Stream<List<NoteModel>> streamNotes({bool newestFirst = true}) {
    return _db
        .collection('notes')
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: newestFirst)
        .snapshots()
        .map((q) => q.docs.map((d) => NoteModel.fromMap(d.data())).toList());
  }

  Future<NoteModel?> getNote(String id) async {
    final doc = await _db.collection('notes').doc(id).get();
    if (!doc.exists) return null;
    return NoteModel.fromMap(doc.data()!);
  }

  // CREATE/UPDATE
  Future<void> upsert(NoteModel m) async {
    final ref = _db.collection('notes').doc(m.id.isEmpty ? _db.collection('notes').doc().id : m.id);
    final snap = await ref.get();

    final body = {
      'id': ref.id,
      'jobId': m.jobId,
      'text': m.text,
      'images': m.images,
      'imagesB64': m.imagesB64,
    };

    if (!snap.exists) {
      // CREATE: must include userId for the rules
      await ref.set({
        ...body,
        'userId': _uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // UPDATE: don't change userId
      await ref.update(body);
    }
  }

  // Use serverTimestamp on create; keep existing createdAt on updates.
  // Future<void> upsert(NoteModel m) async {
  //   final ref = _db.collection('notes').doc(m.id);
  //   final snap = await ref.get();
  //   final data = m.toMap();
  //
  //   if (!snap.exists) {
  //     data['createdAt'] = FieldValue.serverTimestamp(); // set by server
  //   }
  //   await ref.set(data, SetOptions(merge: true));
  // }
  // NotesService.upsert – guarantee userId on create and never change it on update


  // Future<void> upsert(NoteModel m) async {
  //   final notes = _db.collection('notes');
  //   final docId = (m.id.isEmpty) ? notes.doc().id : m.id;
  //   final ref = notes.doc(docId);
  //   final snap = await ref.get();
  //
  //   final body = {
  //     'id': docId,
  //     'jobId': m.jobId,
  //     'text': m.text,
  //     'images': m.images,
  //     'imagesB64': m.imagesB64,
  //   };
  //
  //   if (!snap.exists) {
  //     await ref.set({
  //       ...body,
  //       'userId': _uid,                         // <- set once
  //       'createdAt': FieldValue.serverTimestamp(),
  //     });
  //   } else {
  //     await ref.update(body);                   // <- never touch userId
  //   }
  // }


  Future<void> delete(String id, {List<String> storagePaths = const []}) async {
    await _db.collection('notes').doc(id).delete();
    // Optional: also delete images by storage path (if you store them)
    for (final p in storagePaths) {
      try { await _storage.ref(p).delete(); } catch (_) {}
    }
  }

  /// More robust upload: checks file and uses putData
  Future<({String url, String path})> uploadImage(String noteId, File file) async {
    if (!file.existsSync()) {
      throw StateError('Image not found: ${file.path}');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('Image is empty: ${file.path}');
    }

    final imageId = const Uuid().v4();
    final path = 'notes/$_uid/$noteId/$imageId.jpg';
    final ref = _storage.ref(path);

    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();

    return (url: url, path: path);
  }

  /// Read image, optionally downscale/compress, return a data URI string like "data:image/jpeg;base64,..."
  Future<String> fileToDataUri(File file, {int maxWidth = 900, int jpegQuality = 75}) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Unsupported image: ${file.path}');
    }
    // Downscale to keep Firestore doc small
    final resized = img.copyResize(decoded, width: decoded.width > maxWidth ? maxWidth : decoded.width);
    final jpg = img.encodeJpg(resized, quality: jpegQuality);
    final b64 = base64Encode(jpg);
    return 'data:image/jpeg;base64,$b64';
  }
}
*/

import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:image/image.dart' as img;
import 'note_model.dart';
import 'package:firebase_core/firebase_core.dart';

class NotesService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not authenticated');
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>> get _notes => _db.collection('notes');

  Stream<List<NoteModel>> streamNotes({bool newestFirst = true}) {
    return _notes
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: newestFirst)
        .snapshots()
        .map((q) => q.docs.map(NoteModel.fromDoc).toList());
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

  /// Create or update. On create, set createdAt on the server.
  // Future<void> upsert(NoteModel m) async {
  //   final ref = _notes.doc(m.id);
  //   final snap = await ref.get();
  //   final data = m.toMap();
  //   if (!snap.exists) data['createdAt'] = FieldValue.serverTimestamp();
  //   await ref.set(data, SetOptions(merge: true));
  // }

  Future<void> upsert(NoteModel m) async {
    // final uid = FirebaseAuth.instance.currentUser?.uid;
    // debugPrint('DBG uid=$uid  project=${Firebase.app().options.projectId}');
    // await FirebaseFirestore.instance.doc('notes/__rule_test').set({
    //   'id': '__rule_test222',
    //   'userId': uid,
    //   'text': 'hihi',
    // });
    //
    // final uid = FirebaseAuth.instance.currentUser?.uid;
    // if (uid == null) throw StateError('Not authenticated');
    //
    // final ref = FirebaseFirestore.instance.collection('notes').doc(m.id);
    // final snap = await ref.get();
    //
    // final data = m.toMap()
    //   ..['userId'] = uid; // <— critical
    //
    // if (!snap.exists) data['createdAt'] = FieldValue.serverTimestamp();
    // await ref.set(data, SetOptions(merge: true));

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Not authenticated');

      if (m.jobId.trim().isEmpty) {
        throw StateError('Job is required');
      }

      final ref = FirebaseFirestore.instance.collection('notes').doc(m.id);

      // build data
      final data = m.toMap()
        ..['userId'] = uid;

      // only set createdAt when creating (m.createdAt is null for new notes)
      if (m.createdAt == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      // no pre-read; just merge
      await ref.set(data, SetOptions(merge: true));
  }

  Future<void> delete(String id) async => _notes.doc(id).delete();

  /// Compress to ~900px wide JPEG, return data URI string.
  Future<String> fileToDataUri(File file, {int maxWidth = 900, int quality = 75}) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Unsupported image: ${file.path}');
    }
    final resized = decoded.width > maxWidth
        ? img.copyResize(decoded, width: maxWidth)
        : decoded;
    final jpg = img.encodeJpg(resized, quality: quality);
    final b64 = base64Encode(jpg);
    return 'data:image/jpeg;base64,$b64';
  }
}