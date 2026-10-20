import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/supabase_task_remote.dart';
import 'data/task_store.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/team_setup_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  final store = TaskStore.connected(
    SupabaseTaskRemote(Supabase.instance.client),
  );
  runApp(PrepAdminApp(store: store));
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
          title: 'PrepWisely Team',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _messenger,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: widget.themeMode ?? themeMode,
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

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: c.brandGradient,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.task_alt_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }
}
