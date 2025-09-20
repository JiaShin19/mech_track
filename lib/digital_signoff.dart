import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart'; // <-- for saving locally
import 'package:path/path.dart' as p;

class DigitalSignoffScreen extends StatefulWidget {
  final String jobId;
  final String mechanicId;

  const DigitalSignoffScreen({
    super.key,
    required this.jobId,
    required this.mechanicId,
  });

  @override
  State<DigitalSignoffScreen> createState() => _DigitalSignoffScreenState();
}

class _DigitalSignoffScreenState extends State<DigitalSignoffScreen> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.indigo,
    exportBackgroundColor: Colors.white,
  );
  bool _busy = false;
  String? _uploadedUrl;

  Future<void> _saveSignature() async {
    setState(() => _busy = true);
    try {
      final Uint8List? data = await _controller.toPngBytes();
      if (data == null) throw "Signature is empty.";

      // 1. Save locally into temp directory (simulating "assets/images")
      final dir = await getTemporaryDirectory();
      final filename = "${widget.jobId}_signature.png";
      final localPath = p.join(dir.path, filename);
      final file = File(localPath);
      await file.writeAsBytes(data);

      // 2. Upload to Firebase Storage under /jobs/{jobId}/signature.png
      final storageRef = FirebaseStorage.instance
          .ref()
          .child("jobs/${widget.jobId}/signature.png");
      await storageRef.putFile(file, SettableMetadata(contentType: "image/png"));
      final url = await storageRef.getDownloadURL();

      // 3. Save metadata into Firestore under jobs/{jobId}
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
        'signatureUrl': url,
        'signedOffBy': widget.mechanicId,
        'signedOffAt': FieldValue.serverTimestamp(),
      });

      setState(() => _uploadedUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signature saved & uploaded!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Sign-Off'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Please sign below:",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.indigo),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Signature(
                controller: _controller,
                height: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Clear"),
                  onPressed: _busy ? null : () => _controller.clear(),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text("Sign & Upload"),
                  onPressed: _busy ? null : _saveSignature,
                ),
              ],
            ),
            if (_uploadedUrl != null) ...[
              const SizedBox(height: 20),
              const Text("Signature saved!", style: TextStyle(color: Colors.green)),
              Image.network(_uploadedUrl!, height: 120),
            ]
          ],
        ),
      ),
    );
  }
}
