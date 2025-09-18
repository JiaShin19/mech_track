import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  final String id;
  final String userId;
  final String jobId;
  final String text;
  final List<String> imagesB64;   // <— store images here as data URIs
  final DateTime? createdAt;

  NoteModel({
    required this.id,
    required this.userId,
    required this.jobId,
    required this.text,
    required this.imagesB64,
    this.createdAt,
  });

  factory NoteModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final ts = d['createdAt'];
    return NoteModel(
      id: d['id'] as String,
      userId: d['userId'] as String,
      jobId: (d['jobId'] as String?) ?? '',
      text: (d['text'] as String?) ?? '',
      imagesB64: (d['imagesB64'] as List?)?.cast<String>() ?? const [],
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'jobId': jobId,
    'text': text,
    'imagesB64': imagesB64,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    // createdAt is set on create in the service (serverTimestamp)
  };
}


//
// class NoteModel {
//   final String id;
//   final String userId;
//   final String jobId;
//   final String text;
//   final List<String> images;       // download URLs
//   final List<String> imagePaths;   // storage paths (optional but useful)
//   final DateTime? createdAt;
//
//   NoteModel({
//     required this.id,
//     required this.userId,
//     required this.jobId,
//     required this.text,
//     required this.images,
//     this.imagePaths = const [],
//     this.createdAt,
//   });
//
//   factory NoteModel.fromMap(Map<String, dynamic> m) {
//     final ts = m['createdAt'];
//     return NoteModel(
//       id: m['id'] as String,
//       userId: m['userId'] as String,
//       jobId: (m['jobId'] as String?) ?? '',
//       text: (m['text'] as String?) ?? '',
//       images: (m['images'] as List?)?.cast<String>() ?? const [],
//       imagePaths: (m['imagePaths'] as List?)?.cast<String>() ?? const [],
//       createdAt: ts is Timestamp ? ts.toDate() : null,
//     );
//   }
//
//   Map<String, dynamic> toMap() => {
//     'id': id,
//     'userId': userId,
//     'jobId': jobId,
//     'text': text,
//     'images': images,
//     'imagePaths': imagePaths,
//     // createdAt set by service on create (serverTimestamp)
//   };
// }
