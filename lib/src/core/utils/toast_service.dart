import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/success_toast.dart';

class ToastService {
  OverlayEntry? _currentEntry;

  void showSuccess(BuildContext context, String message) {
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => SuccessToast(
        message: message,
        onDismiss: () {
          if (_currentEntry == entry) {
            _currentEntry = null;
          }
          entry.remove();
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

final toastServiceProvider = Provider((ref) => ToastService());
