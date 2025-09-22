import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';

class UpdateProfilePage extends StatefulWidget {
  final String fieldName;
  final String currentValue;

  const UpdateProfilePage({
    super.key,
    required this.fieldName,
    required this.currentValue,
  });

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> {
  late final TextEditingController _oldController;
  late final TextEditingController _newController;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _oldController = TextEditingController(text: widget.currentValue);
    _newController = TextEditingController();
  }

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    super.dispose();
  }

  // Friendly label → Firestore key (matches your DB)
  String _mapFieldKey(String friendly) {
    final f = friendly.toLowerCase();
    if (f.contains('phone'))   return 'phone';
    if (f.contains('address')) return 'address';
    if (f.contains('name'))    return 'name';
    if (f.contains('staff'))   return 'id';
    return friendly;
  }

  Future<void> _updateField() async {
    final newValue = _newController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _errorText = null);

    if (newValue.isEmpty) {
      setState(() => _errorText = "${widget.fieldName} is required");
      return;
    }

    final field = _mapFieldKey(widget.fieldName);

    if (field == 'name') {
      await user.updateDisplayName(newValue);
    }

    // Light validations
    if (field == 'phone') {
      final phoneRegex = RegExp(r'^\d{2,4}-\d{3,4}-\d{3,4}$');
      if (!phoneRegex.hasMatch(newValue)) {
        setState(() => _errorText = "Use format like 019-789-9090");
        return;
      }
    } else if (field == 'address') {
      final addressRegex =
      RegExp(r'.*(jalan|lorong|taman|persiaran).*', caseSensitive: false);
      if (!addressRegex.hasMatch(newValue)) {
        setState(() => _errorText =
        "Address should contain Jalan/Lorong/Taman/Persiaran");
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final box = await Hive.openBox('profileCache');
      final cached = (box.get(user.uid) as Map?) ?? {};
      final updated = {
        ...cached,
        field: newValue,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await box.put(user.uid, updated);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${widget.fieldName} updated locally")),
        );
      }
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          field: newValue,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorText = "Failed to update locally: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Consistent header
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
                const Icon(Icons.edit_note, color: Color(0xFF2B384C), size: 22),
                const SizedBox(width: 12),
                Text('Update ${widget.fieldName}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _oldController,
                    readOnly: true,
                    decoration:
                    InputDecoration(labelText: 'Current ${widget.fieldName}'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _newController,
                    decoration: InputDecoration(
                      labelText: 'New ${widget.fieldName}',
                      errorText: _errorText,
                      filled: _errorText != null,
                      fillColor: _errorText != null ? Colors.red[50] : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _isSaving
                      ? const CircularProgressIndicator()
                      : FilledButton.icon(
                    onPressed: _updateField,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2B384C),
                      foregroundColor: const Color(0xFFF0F4F3),
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
}
