import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  final String id;
  final String userId;
  final String jobId;
  String title;
  final String text;
  final List<String> imagesB64;   // <— store images here as data URIs
  final DateTime? createdAt;

  NoteModel({
    required this.id,
    required this.userId,
    required this.jobId,
    required this.title,
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
      title: d['title'] as String ?? '',
      text: (d['text'] as String?) ?? '',
      imagesB64: (d['imagesB64'] as List?)?.cast<String>() ?? const [],
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'jobId': jobId,
    'title': title,
    'text': text,
    'imagesB64': imagesB64,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
  };
}
