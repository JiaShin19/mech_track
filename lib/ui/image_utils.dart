import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

Widget placeholderThumb({double w = 56, double h = 56}) {
  return Container(
    width: w, height: h,
    color: Colors.grey.shade200,
    alignment: Alignment.center,
    child: const Icon(Icons.image, color: Colors.grey),
  );
}

class _XPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFB7B7B7)
      ..strokeWidth = 2;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), p);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), p);
  }
  @override
  bool shouldRepaint(_) => false;
}

Uint8List? _bytesFromMaybeDataUri(String s) {
  if (s.isEmpty) return null;

  // True data URI
  if (s.startsWith('data:')) {
    try {
      final data = Uri.parse(s).data;
      return data?.contentAsBytes();
    } catch (_) {
      return null;
    }
  }

  // Bare base64 (no data: prefix)
  final idx = s.indexOf(',');
  final base64Part = (idx >= 0) ? s.substring(idx + 1) : s;
  try {
    return base64Decode(base64Part);
  } catch (_) {
    return null;
  }
}

/// Shows an image from:
///  data URI / base64 -> Image.memory
///  http/https URL    -> Image.network
///  otherwise         -> placeholder
Widget smartThumb(
    String src, {
      double w = 56,
      double h = 56,
      BoxFit fit = BoxFit.cover,
    }) {
  // data/base64
  final bytes = _bytesFromMaybeDataUri(src);
  if (bytes != null) {
    return Image.memory(
      bytes, width: w, height: h, fit: fit, gaplessPlayback: true,
      errorBuilder: (_, __, ___) => placeholderThumb(w: w, h: h),
    );
  }

  // http/https
  if (src.startsWith('http://') || src.startsWith('https://')) {
    return Image.network(
      src, width: w, height: h, fit: fit,
      errorBuilder: (_, __, ___) => placeholderThumb(w: w, h: h),
    );
  }

  return placeholderThumb(w: w, h: h);
}
