import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/task_store.dart';

/// Shows the state of the connection on every screen:
/// - a "No internet" strip across the top while the server can't be reached,
/// - a "Reconnecting" strip while teammates' changes aren't arriving live,
/// - a thin progress line while data is being loaded or saved.
///
/// The tree under it never changes shape, so screens keep their state when
/// the strip comes and goes; they just lose the status-bar padding the strip
/// now covers.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, required this.store, required this.child});

  final TaskStore store;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store.online, store.live, store.syncing]),
      builder: (context, _) {
        final media = MediaQuery.of(context);
        final strip = !store.online.value
            ? _Strip(
                top: media.padding.top,
                icon: Icons.wifi_off_rounded,
                text: 'No internet connection',
              )
            : !store.live.value
            ? _Strip(
                top: media.padding.top,
                icon: Icons.sync_rounded,
                text: 'Reconnecting… updates may be late',
              )
            : null;
        return Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: strip ?? const SizedBox(width: double.infinity),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MediaQuery(
                    data: strip == null
                        ? media
                        : media.removePadding(removeTop: true),
                    child: child,
                  ),
                  // Only built while busy: an idle indicator still animates.
                  if (store.syncing.value)
                    Positioned(
                      top: strip == null ? media.padding.top : 0,
                      left: 0,
                      right: 0,
                      child: const IgnorePointer(
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.top, required this.icon, required this.text});

  final double top;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: const Color(0xFF1F2030),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, top + 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: const Color(0xFFFDB022)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(
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
