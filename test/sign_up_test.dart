import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prep_admin/data/supabase_task_remote.dart';
import 'package:prep_admin/data/task_remote.dart';
import 'package:prep_admin/data/task_store.dart';
import 'package:prep_admin/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _user = {
  'id': '00000000-0000-4000-8000-000000000001',
  'aud': 'authenticated',
  'email': 'new@example.com',
  'app_metadata': <String, dynamic>{},
  'user_metadata': {'full_name': 'New Person'},
  'created_at': '2026-10-22T10:00:00Z',
};

/// Answers sign-up with [body], as the auth server would.
SupabaseClient _clientAnswering(Map<String, dynamic> body) => SupabaseClient(
  'https://example.supabase.co',
  'test-key',
  httpClient: MockClient(
    (_) async => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    ),
  ),
  authOptions: const AuthClientOptions(
    authFlowType: AuthFlowType.implicit,
    autoRefreshToken: false,
  ),
);

/// Signed out, and sign-up always wants the email confirmed first.
class _ConfirmFirstRemote extends SupabaseTaskRemote {
  _ConfirmFirstRemote() : super(_clientAnswering(_user));

  @override
  Stream<String?> get userIds => Stream.value(null);

  @override
  Future<({String userId, RemoteSnapshot snapshot})?> cachedSnapshot() async =>
      null;

  @override
  Future<void> ping() async {}

  @override
  Future<void> clearCache() async {}

  @override
  void stopListening() {}

  @override
  Future<bool> signUp(String fullName, String email, String password) async =>
      false;
}

void main() {
  // ignore: invalid_use_of_visible_for_testing_member
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sign-up with "Confirm email" on reports no sign-in', () async {
    final client = _clientAnswering(_user);
    expect(
      await SupabaseTaskRemote(client).signUp('New', 'new@example.com', 'pw'),
      isFalse,
    );
    await client.dispose();
  });

  test('sign-up with "Confirm email" off reports a sign-in', () async {
    final client = _clientAnswering({
      'access_token': 'token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'refresh',
      'user': _user,
    });
    expect(
      await SupabaseTaskRemote(client).signUp('New', 'new@example.com', 'pw'),
      isTrue,
    );
    await client.dispose();
  });

  testWidgets('sign-up that needs email confirmation says so', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = TaskStore.connected(
      _ConfirmFirstRemote(),
      watchNetwork: false,
    );
    await tester.pumpWidget(PrepAdminApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'New Person');
    await tester.enterText(find.byType(TextFormField).at(1), 'new@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password-123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('We sent a link to new@example.com'), findsOne);
    // Back on sign-in with the email kept; nobody is signed in.
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.text('new@example.com'), findsOneWidget);
    expect(store.currentUser, isNull);

    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
