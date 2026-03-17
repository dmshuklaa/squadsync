import 'package:flutter/material.dart';

/// Lightweight overlay toast that appears centred near the bottom of the
/// screen, stays for 1 second, then fades out over 400 ms.
abstract final class SaveToast {
  static void show(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SaveToastOverlay(
        message: message,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _SaveToastOverlay extends StatefulWidget {
  const _SaveToastOverlay({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  State<_SaveToastOverlay> createState() => _SaveToastOverlayState();
}

class _SaveToastOverlayState extends State<_SaveToastOverlay> {
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    // Start fade-out after 1 s
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _opacity = 0.0);
    });
    // Remove overlay after fade completes
    Future.delayed(const Duration(milliseconds: 1500), widget.onDismiss);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 400),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.message,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
