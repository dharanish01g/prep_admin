import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "No internet" strip across the top of every screen while [online] is
/// false. The tree under it never changes shape, so screens keep their state
/// when the banner comes and goes; they just lose the status-bar padding the
/// banner now covers.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.online, required this.child});

  final ValueListenable<bool> online;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: online,
      builder: (context, isOnline, _) {
        final media = MediaQuery.of(context);
        return Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: isOnline
                  ? const SizedBox(width: double.infinity)
                  : _Strip(top: media.padding.top),
            ),
            Expanded(
              child: MediaQuery(
                data: isOnline ? media : media.removePadding(removeTop: true),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.top});

  final double top;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: const Color(0xFF1F2030),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, top + 8, 16, 8),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 18, color: Color(0xFFFDB022)),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'No internet connection',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
