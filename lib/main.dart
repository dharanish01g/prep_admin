import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'config.dart';
import 'data/supabase_task_remote.dart';
import 'data/task_store.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/team_setup_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/offline_banner.dart';

Future<void> main() async {
  await SentryFlutter.init((options) {
    options.dsn = sentryDsn;
    options.environment = kReleaseMode ? 'production' : 'development';
    // No IP address or names; reports carry only the anonymous user id below.
    options.sendDefaultPii = false;
    options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
  }, appRunner: _run);
}

void _run() {
  // Draw first; Supabase starts in the background (see
  // SupabaseTaskRemote.initialize) while the store opens from its saved copy.
  final store = TaskStore.connected(SupabaseTaskRemote.initialize());
  // Tag reports with who hit them, so one person's problem can be followed.
  String? reportedUser;
  store.addListener(() {
    final id = store.currentUser?.id;
    if (id == reportedUser) return;
    reportedUser = id;
    Sentry.configureScope(
      (scope) => scope.setUser(id == null ? null : SentryUser(id: id)),
    );
  });
  runApp(SentryWidget(child: PrepAdminApp(store: store)));
}

class PrepAdminApp extends StatefulWidget {
  const PrepAdminApp({super.key, required this.store, this.themeMode});

  final TaskStore store;
  final ThemeMode? themeMode;

  @override
  State<PrepAdminApp> createState() => _PrepAdminAppState();
}

class _PrepAdminAppState extends State<PrepAdminApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    widget.store.onError = (message) =>
        _messenger.currentState?.showSnackBar(SnackBar(content: Text(message)));
    // Back from the background: pick up whatever teammates changed meanwhile.
    _lifecycle = AppLifecycleListener(onResume: widget.store.refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: widget.store,
      child: ValueListenableBuilder(
        valueListenable: widget.store.themeMode,
        builder: (context, themeMode, _) => MaterialApp(
          title: 'Tiny Tasks',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _messenger,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: widget.themeMode ?? themeMode,
          builder: (context, child) =>
              OfflineBanner(online: widget.store.online, child: child!),
          home: const _Root(),
        ),
      ),
    );
  }
}

/// Login until someone signs in, then team setup until they're in a team.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.starting) return const _Splash();
    if (store.currentUser == null) return const LoginScreen();
    if (store.currentTeam == null) return const NoTeamScreen();
    return const HomeScreen();
  }
}

/// Same colour and image as the native launch screen (see
/// `flutter_native_splash` in pubspec.yaml; Android 12+ draws it at 288dp),
/// so the hand-over is invisible. Usually gone at once: signed-in users open
/// from their saved copy. If loading is slow it says so after 2 seconds
/// instead of showing only the logo.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final slow = StoreScope.of(context).slowStart;
    return Scaffold(
      backgroundColor: const Color(0xFF6D5DFC),
      body: Stack(
        alignment: Alignment.center,
        children: [
          const Image(
            image: AssetImage('assets/icon/splash.png'),
            width: 288,
            height: 288,
          ),
          if (slow)
            const Positioned(
              bottom: 96,
              child: Column(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Loading your tasks…',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
