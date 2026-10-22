// Runs the real app store against the live prep-admin Supabase project with
// two throwaway accounts. Not part of `flutter test`; run it on purpose:
//   flutter test test_live/remote_test.dart
// Both accounts delete themselves at the end; if a run fails midway, it
// prints the accounts it made so they can be deleted by hand.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:prep_admin/config.dart';
import 'package:prep_admin/data/supabase_task_remote.dart';
import 'package:prep_admin/data/task_remote.dart';
import 'package:prep_admin/data/task_store.dart';
import 'package:prep_admin/models/task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient newClient({http.Client? httpClient}) => SupabaseClient(
  supabaseUrl,
  supabasePublishableKey,
  httpClient: httpClient,
  authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
);

/// Sends requests whose path ends with one of [drop], then loses the
/// answer, like a connection dying the moment the server is done.
class LosesAnswers extends http.BaseClient {
  LosesAnswers(this.drop);
  final List<String> drop;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (drop.any(request.url.path.endsWith)) {
      await response.stream.drain<void>();
      throw const SocketException('Connection lost');
    }
    return response;
  }
}

Future<void> waitFor(
  String what,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for: $what');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

/// A server that takes [delay] to answer, to show the app doesn't wait on it.
class SlowRemote extends SupabaseTaskRemote {
  SlowRemote(super.db, this.delay);
  final Duration delay;

  @override
  Future<RemoteSnapshot> fetch() async {
    await Future<void>.delayed(delay);
    return super.fetch();
  }
}

/// A server that can be switched off, like losing the internet.
class FlakyRemote extends SupabaseTaskRemote {
  FlakyRemote(super.db);
  bool down = true;

  Future<void> _check() async {
    if (down) {
      onReachability?.call(false);
      throw const TaskRemoteException('offline', offline: true);
    }
  }

  @override
  Future<RemoteSnapshot> fetch() async {
    await _check();
    return super.fetch();
  }

  @override
  Future<void> ping() async {
    await _check();
    return super.ping();
  }
}

void main() {
  // Prefs live in memory here, as on a fresh install.
  // ignore: invalid_use_of_visible_for_testing_member
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'reopening shows the saved copy without waiting for the server',
    () async {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final email = 'qa.cache.$stamp@example.com';
      // ignore: avoid_print
      print('TEST ACCOUNT: $email');
      final client = newClient();

      final first = TaskStore.connected(
        SupabaseTaskRemote(client),
        watchNetwork: false,
      );
      await waitFor('start', () => !first.starting);
      expect(
        await first.signUp(
          fullName: 'Cache QA',
          email: email,
          password: 'password-123',
        ),
        isNull,
      );
      await waitFor(
        'loaded',
        () => first.currentUser != null && !first.starting,
      );
      await first.createTeam(name: 'Cache Team', colorIndex: 1);
      final task = first.addTask(
        title: 'Saved for later',
        scope: TaskScope.personal,
      );
      // Adding syncs in the background; reload until the server has it, which
      // also saves the copy the next launch opens from.
      for (var i = 0; i < 50; i++) {
        await first.refresh();
        if (first.taskById(task.id) != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      expect(first.taskById(task.id), isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      first.dispose();

      // Same session, next launch, with a server that takes 5 seconds.
      final second = TaskStore.connected(
        SlowRemote(client, const Duration(seconds: 5)),
        watchNetwork: false,
      );
      await waitFor(
        'opened from saved copy',
        () => !second.starting,
        timeout: const Duration(seconds: 2),
      );
      expect(second.me.fullName, 'Cache QA');
      expect(second.currentTeam?.name, 'Cache Team');
      expect(second.taskById(task.id)?.title, 'Saved for later');

      // Signing out (here via deleting the account) forgets the saved copy.
      await second.deleteAccount();
      await waitFor('signed out', () => second.currentUser == null);
      final remote = SupabaseTaskRemote(client);
      for (var i = 0; i < 20; i++) {
        if (await remote.cachedSnapshot() == null) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(await remote.cachedSnapshot(), isNull);
      second.dispose();
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test('latest release is readable without signing in', () async {
    final release = await SupabaseTaskRemote(newClient())
        .latestRelease('android');
    expect(release?.version, matches(RegExp(r'^\d+(\.\d+)*$')));
  });

  test('offline: opens from the saved copy, then recovers', () async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'qa.offline.$stamp@example.com';
    // ignore: avoid_print
    print('TEST ACCOUNT: $email');
    final client = newClient();

    final first = TaskStore.connected(
      SupabaseTaskRemote(client),
      watchNetwork: false,
    );
    await waitFor('start', () => !first.starting);
    expect(
      await first.signUp(
        fullName: 'Offline QA',
        email: email,
        password: 'password-123',
      ),
      isNull,
    );
    await waitFor('loaded', () => first.currentUser != null && !first.starting);
    await first.createTeam(name: 'Offline Team', colorIndex: 3);
    await first.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    first.dispose();

    final remote = FlakyRemote(client);
    final app = TaskStore.connected(remote, watchNetwork: false);
    await waitFor(
      'home from saved copy',
      () => !app.starting,
      timeout: const Duration(seconds: 2),
    );
    expect(app.currentTeam?.name, 'Offline Team');
    await waitFor('banner on', () => !app.online.value);

    remote.down = false;
    await app.refresh();
    expect(app.online.value, isTrue);
    expect(app.currentTeam?.name, 'Offline Team');

    await app.deleteAccount();
    await waitFor('signed out', () => app.currentUser == null);
    app.dispose();
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('deleting the account works when its answers are lost', () async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'qa.delete.$stamp@example.com';
    // ignore: avoid_print
    print('TEST ACCOUNT: $email');
    final store = TaskStore.connected(
      SupabaseTaskRemote(
        newClient(
          httpClient: LosesAnswers(['/rpc/ic_delete_account', '/logout']),
        ),
      ),
      watchNetwork: false,
    );
    await waitFor('start', () => !store.starting);
    expect(
      await store.signUp(
        fullName: 'Delete QA',
        email: email,
        password: 'password-123',
      ),
      isNull,
    );
    await waitFor('signed in', () => store.currentUser != null);
    await store.createTeam(name: 'QA Delete', colorIndex: 0);

    await store.deleteAccount();
    await waitFor('signed out', () => store.currentUser == null);
    final check = TaskStore.connected(
      SupabaseTaskRemote(newClient()),
      watchNetwork: false,
    );
    await waitFor('check start', () => !check.starting);
    expect(
      await check.signInWithEmail(email, 'password-123'),
      'Wrong email or password.',
    );
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('two people share a team through Supabase', () async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final aliceEmail = 'qa.alice.$stamp@example.com';
    final bobEmail = 'qa.bob.$stamp@example.com';
    // ignore: avoid_print
    print('TEST ACCOUNTS: $aliceEmail $bobEmail');
    final errors = <String>[];

    final alice = TaskStore.connected(
      SupabaseTaskRemote(newClient()),
      watchNetwork: false,
    )..onError = errors.add;
    await waitFor('alice start', () => !alice.starting);
    expect(
      await alice.signUp(
        fullName: 'Alice QA',
        email: aliceEmail,
        password: 'password-123',
      ),
      isNull,
    );
    await waitFor('alice signed in', () => alice.currentUser != null);
    await waitFor('alice loaded', () => !alice.starting);
    expect(alice.me.fullName, 'Alice QA');
    expect(alice.currentTeam, isNull);

    final team = await alice.createTeam(name: 'QA Team', colorIndex: 2);
    expect(alice.currentTeam?.id, team.id);
    expect(alice.isOwner(team.id), isTrue);
    expect(team.joinCode, matches(RegExp(r'^[A-Z0-9]{6}$')));

    final bob = TaskStore.connected(
      SupabaseTaskRemote(newClient()),
      watchNetwork: false,
    )..onError = errors.add;
    await waitFor('bob start', () => !bob.starting);
    expect(
      await bob.signUp(
        fullName: 'Bob QA',
        email: bobEmail,
        password: 'password-123',
      ),
      isNull,
    );
    await waitFor('bob signed in', () => bob.currentUser != null);
    await waitFor('bob loaded', () => !bob.starting);

    expect(await bob.previewTeam('ZZZZZZ'), isNull);
    final preview = await bob.previewTeam(team.joinCode.toLowerCase());
    expect(preview?.name, 'QA Team');
    expect(preview?.memberCount, 1);
    expect(preview?.isMember, isFalse);

    await bob.joinTeam(team.joinCode);
    expect(bob.currentTeam?.name, 'QA Team');
    expect(bob.members.map((m) => m.fullName), ['Alice QA', 'Bob QA']);

    // Alice hears about Bob live.
    await waitFor('alice sees bob', () => alice.members.length == 2);

    // Renaming in Settings reaches teammates live.
    await alice.updateName('Alice Renamed');
    expect(alice.me.fullName, 'Alice Renamed');
    await waitFor(
      'bob sees the new name',
      () => bob.memberById(alice.me.id)?.fullName == 'Alice Renamed',
    );

    final task = alice.addTask(
      title: 'Prepare the demo',
      scope: TaskScope.common,
      assignedTo: bob.me.id,
      dueDate: DateTime(2026, 10, 25),
    );
    await waitFor(
      'bob receives task',
      () => bob.assignedToMe.any((t) => t.id == task.id),
    );
    expect(bob.taskById(task.id)!.dueDate, DateTime(2026, 10, 25));

    bob.setStatus(bob.taskById(task.id)!, TaskStatus.done);
    await waitFor(
      'alice sees it done',
      () => alice.taskById(task.id)?.completedAt != null,
    );

    // Bob is only the assignee: the server refuses anything but status.
    bob.updateTask(bob.taskById(task.id)!.copyWith(title: 'Renamed by Bob'));
    await waitFor('bob is refused', () => errors.isNotEmpty);
    expect(errors.removeLast(), contains('creator'));
    await waitFor(
      'title restored',
      () => bob.taskById(task.id)?.title == 'Prepare the demo',
    );

    // Not creator nor assignee: the rules skip the row without an error, so
    // the app has to notice nothing changed, say so and put it back.
    final aliceOnly = alice.addTask(
      title: 'Alice only',
      scope: TaskScope.common,
    );
    await waitFor('bob sees it', () => bob.taskById(aliceOnly.id) != null);
    bob.setStatus(bob.taskById(aliceOnly.id)!, TaskStatus.inProgress);
    await waitFor('bob is refused the edit', () => errors.isNotEmpty);
    expect(errors.removeLast(), contains("can't change this task"));
    await waitFor(
      'status restored',
      () => bob.taskById(aliceOnly.id)?.status == TaskStatus.todo,
    );
    bob.deleteTask(aliceOnly.id);
    await waitFor('bob is refused the delete', () => errors.isNotEmpty);
    expect(errors.removeLast(), contains("can't delete this task"));
    await waitFor('task restored', () => bob.taskById(aliceOnly.id) != null);

    // Deleted elsewhere: an edit says so; deleting it again is fine.
    final stale = bob.taskById(aliceOnly.id)!;
    alice.deleteTask(aliceOnly.id);
    await waitFor('alice deleted', () => bob.taskById(aliceOnly.id) == null);
    await expectLater(
      bob.remote!.updateTask(stale.copyWith(status: TaskStatus.done)),
      throwsA(
        isA<TaskRemoteException>().having(
          (e) => e.message,
          'message',
          contains('Someone deleted this task'),
        ),
      ),
    );
    await alice.remote!.deleteTask(aliceOnly.id);

    // Only the owner can change the team, even bypassing the app's check.
    await expectLater(
      bob.remote!.updateTeam(team.id, name: 'Taken over'),
      throwsA(
        isA<TaskRemoteException>().having(
          (e) => e.message,
          'message',
          contains('Only the team owner'),
        ),
      ),
    );

    // Only the owner can make a new code.
    await expectLater(
      SupabaseTaskRemote(newClient()).regenerateJoinCode(team.id),
      throwsA(isA<TaskRemoteException>()),
    );
    final before = alice.currentTeam!.joinCode;
    await alice.regenerateJoinCode(team.id);
    expect(alice.currentTeam!.joinCode, isNot(before));

    // Owner leaves: Bob takes over; Alice is left with no team.
    await alice.leaveTeam(team.id);
    expect(alice.currentTeam, isNull);
    await waitFor('bob is owner', () => bob.isOwner(team.id));

    // Alice comes back, then deletes her account: her common task stays
    // with the team and she can no longer sign in.
    await alice.joinTeam(bob.currentTeam!.joinCode);
    await waitFor('bob sees alice back', () => bob.members.length == 2);
    await alice.deleteAccount();
    await waitFor('alice signed out', () => alice.currentUser == null);
    await waitFor('alice gone for bob', () => bob.members.length == 1);
    await waitFor(
      'task kept, creator cleared',
      () => bob.taskById(task.id)?.createdBy == '',
    );
    expect(
      await alice.signInWithEmail(aliceEmail, 'password-123'),
      'Wrong email or password.',
    );

    // Last one out: Bob's deletion takes the team with it.
    await bob.deleteAccount();
    await waitFor('bob signed out', () => bob.currentUser == null);
    final check = TaskStore.connected(
      SupabaseTaskRemote(newClient()),
      watchNetwork: false,
    );
    await waitFor('check start', () => !check.starting);
    expect(
      await check.signInWithEmail(bobEmail, 'password-123'),
      'Wrong email or password.',
    );

    expect(errors, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
