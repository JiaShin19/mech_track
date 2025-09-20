import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

      // Upload to Firebase Storage
      final filename = "${widget.jobId}_${DateTime.now().millisecondsSinceEpoch}.png";
      final ref = FirebaseStorage.instance.ref("signatures/$filename");
      await ref.putData(data, SettableMetadata(contentType: "image/png"));
      final url = await ref.getDownloadURL();

      // Save metadata to Firestore
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
          const SnackBar(content: Text("Signature uploaded!"))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"))
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
            Text("Please sign below:", style: Theme.of(context).textTheme.titleMedium),
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
              Text("Signature saved!", style: TextStyle(color: Colors.green)),
              Image.network(_uploadedUrl!, height: 120),
            ]
          ],
        ),
      ),
    );
  }
}