import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _saving = false;
  String? _previewB64;

  Future<void> _saveSignature() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final Uint8List? bytes = await _controller.toPngBytes();
      if (bytes == null) throw "Signature is empty";

      // Convert to base64 data URI (like NoteEditorPage)
      final base64Str = base64Encode(bytes);
      final dataUri = "data:image/png;base64,$base64Str";

      // Save into Firestore under jobs/{jobId}
      await FirebaseFirestore.instance
          .collection("jobs")
          .doc(widget.jobId)
          .update({
        "signatureB64": dataUri,
        "signedOffBy": widget.mechanicId,
        "signedOffAt": FieldValue.serverTimestamp(),
        "signedOffUid": FirebaseAuth.instance.currentUser?.uid,
      });

      setState(() => _previewB64 = dataUri);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signature saved to Firestore!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Digital Sign-Off")),
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
                  onPressed: _saving ? null : () => _controller.clear(),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Clear"),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _saveSignature,
                  icon: const Icon(Icons.save),
                  label: const Text("Sign & Save"),
                ),
              ],
            ),
            if (_previewB64 != null) ...[
              const SizedBox(height: 20),
              const Text("Preview:", style: TextStyle(color: Colors.green)),
              Image.memory(
                base64Decode(_previewB64!.split(",").last),
                height: 120,
              ),
            ]
          ],
        ),
      ),
    );
  }
}
