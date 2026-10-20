// Runs the real app store against the live prep-admin Supabase project with
// two throwaway accounts. Not part of `flutter test`; run it on purpose:
//   flutter test test_live/remote_test.dart
// Both accounts delete themselves at the end; if a run fails midway, it
// prints the accounts it made so they can be deleted by hand.

import 'package:flutter_test/flutter_test.dart';
import 'package:prep_admin/config.dart';
import 'package:prep_admin/data/supabase_task_remote.dart';
import 'package:prep_admin/data/task_remote.dart';
import 'package:prep_admin/data/task_store.dart';
import 'package:prep_admin/models/task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient newClient() => SupabaseClient(
  supabaseUrl,
  supabasePublishableKey,
  authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
);

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

void main() {
  test('two people share a team through Supabase', () async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final aliceEmail = 'qa.alice.$stamp@example.com';
    final bobEmail = 'qa.bob.$stamp@example.com';
    // ignore: avoid_print
    print('TEST ACCOUNTS: $aliceEmail $bobEmail');
    final errors = <String>[];

    final alice = TaskStore.connected(SupabaseTaskRemote(newClient()))
      ..onError = errors.add;
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

    final bob = TaskStore.connected(SupabaseTaskRemote(newClient()))
      ..onError = errors.add;
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
    final check = TaskStore.connected(SupabaseTaskRemote(newClient()));
    await waitFor('check start', () => !check.starting);
    expect(
      await check.signInWithEmail(bobEmail, 'password-123'),
      'Wrong email or password.',
    );

    expect(errors, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
