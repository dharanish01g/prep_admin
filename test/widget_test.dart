import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prep_admin/data/task_store.dart';
import 'package:prep_admin/main.dart';
import 'package:prep_admin/models/task.dart';
import 'package:prep_admin/models/team.dart';

Future<TaskStore> pumpSignedIn(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final store = TaskStore.mock();
  await tester.pumpWidget(PrepAdminApp(store: store));
  await tester.ensureVisible(find.text('Arun'));
  await tester.tap(find.text('Arun'));
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
  return store;
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('unknown email is rejected', (tester) async {
    await tester.pumpWidget(PrepAdminApp(store: TaskStore.mock()));
    await tester.enterText(find.byType(TextFormField).at(0), 'nobody@x.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'pw');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('No account for this email.'), findsOneWidget);
  });

  testWidgets('sign in shows My Tasks', (tester) async {
    await pumpSignedIn(tester);
    expect(find.textContaining(', Arun'), findsOneWidget);
    expect(find.text('Weekly progress report'), findsOneWidget);
  });

  testWidgets('create a personal to-do', (tester) async {
    final store = await pumpSignedIn(tester);
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Buy markers');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Buy markers'), findsOneWidget);
    final task = store.myPersonalTasks.firstWhere(
      (t) => t.title == 'Buy markers',
    );
    expect(task.assignedTo, store.me.id);
  });

  testWidgets('ticking a task marks it done', (tester) async {
    final store = await pumpSignedIn(tester);
    await tester.tap(find.byTooltip('Mark as done').first);
    await tester.pump();
    expect(store.myPersonalTasks.where((t) => t.isDone).length, 2);
    expect(
      store.myPersonalTasks
          .where((t) => t.isDone)
          .every((t) => t.completedAt != null),
      isTrue,
    );
  });

  testWidgets('team board and team tabs render', (tester) async {
    await pumpSignedIn(tester);
    await tester.tap(find.text('Board'));
    await tester.pumpAndSettle();
    expect(
      find.text('Add 20 aptitude questions on percentages'),
      findsNothing,
      reason: 'in-progress task lives on the In progress tab',
    );
    await tester.tap(find.text('In progress'));
    await tester.pumpAndSettle();
    expect(
      find.text('Add 20 aptitude questions on percentages'),
      findsOneWidget,
    );

    await tester.tap(find.text('Team').last);
    await tester.pumpAndSettle();
    expect(find.text('Arun Kumar'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('switching team swaps everything over', (tester) async {
    final store = await pumpSignedIn(tester);
    expect(find.text('Weekly progress report'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('Switch team')).first);
    await tester.pumpAndSettle();
    expect(find.text('Your teams'), findsOneWidget);
    await tester.tap(find.text('Acme Tutors'));
    await tester.pumpAndSettle();

    expect(store.currentTeam!.name, 'Acme Tutors');
    expect(find.text('Update parents WhatsApp group'), findsOneWidget);
    expect(find.text('Weekly progress report'), findsNothing);
  });

  testWidgets('join a team with an invite code', (tester) async {
    final store = await pumpSignedIn(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('Switch team')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join with a code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'nope00');
    await tester.pumpAndSettle();
    expect(find.textContaining('No team uses this code'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'camp99');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join Campus Connect'));
    await tester.pumpAndSettle();

    expect(store.currentTeam!.name, 'Campus Connect');
    expect(store.isMemberOf('tm3'), isTrue);
    expect(find.text('Joined Campus Connect'), findsOneWidget);
  });

  testWidgets('invite code is reachable from the team switcher', (
    tester,
  ) async {
    final store = await pumpSignedIn(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('Switch team')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite people to PrepWisely'));
    await tester.pumpAndSettle();
    expect(find.text(store.currentTeam!.joinCode), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('someone with no team sees the welcome screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = TaskStore.mock();
    store.signIn(store.memberByEmail('nisha@team.test')!);
    await tester.pumpWidget(PrepAdminApp(store: store));

    expect(find.text('Welcome, Nisha!'), findsOneWidget);
    await tester.tap(find.text('Create a team'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Support Crew');
    await tester.tap(find.widgetWithText(FilledButton, 'Create team'));
    await tester.pumpAndSettle();

    final team = store.currentTeam!;
    expect(team.name, 'Support Crew');
    expect(store.isOwner(team.id), isTrue);
    expect(find.text('Support Crew is ready'), findsOneWidget);
    expect(find.text(team.joinCode), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(find.text('Personal'), findsOneWidget);
  });

  test('tasks never leak between teams', () {
    final store = TaskStore.mock();
    store.signIn(store.memberByEmail('arun@team.test')!);
    store.selectTeam('tm2');
    expect(store.myPersonalTasks.map((t) => t.id), ['a5']);
    expect(store.commonTasks.every((t) => t.teamId == 'tm2'), isTrue);
    expect(store.members.map((m) => m.id), ['m6', 'm1', 'm7']);

    final t = store.addTask(title: 'Acme only', scope: TaskScope.personal);
    expect(t.teamId, 'tm2');
    store.selectTeam('tm1');
    expect(store.myPersonalTasks.any((x) => x.id == t.id), isFalse);
  });

  test('owner leaving hands over; last one out deletes the team', () async {
    final store = TaskStore.mock();
    store.signIn(store.memberByEmail('arun@team.test')!);
    await store.leaveTeam('tm1');
    expect(store.isMemberOf('tm1'), isFalse);
    expect(store.membership('tm1', 'm2')!.role, TeamRole.owner);
    expect(store.currentTeam!.id, 'tm2');
    // Arun's tm1 tasks are unassigned, his personal to-dos gone.
    expect(store.taskById('t4')!.assignedTo, isNull);
    expect(store.taskById('p1'), isNull);

    final solo = await store.createTeam(name: 'Solo', colorIndex: 2);
    expect(solo.joinCode.length, 6);
    await store.leaveTeam(solo.id);
    expect(store.teamById(solo.id), isNull);
  });

  testWidgets('create an account (mock)', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = TaskStore.mock();
    await tester.pumpWidget(PrepAdminApp(store: store));
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Kavya Iyer');
    await tester.enterText(fields.at(1), 'kavya@team.test');
    await tester.enterText(fields.at(2), 'short');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    expect(find.text('Use at least 8 characters'), findsOneWidget);

    await tester.enterText(fields.at(2), 'longenough');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(store.currentUser!.fullName, 'Kavya Iyer');
    expect(find.text('Welcome, Kavya!'), findsOneWidget);
  });

  test('switching a task to personal reassigns it to its creator', () {
    final store = TaskStore.mock();
    store.signIn(store.allMembers.first);
    final t = store.commonTasks.firstWhere((t) => t.createdBy != t.assignedTo);
    store.updateTask(t.copyWith(scope: TaskScope.personal));
    expect(store.taskById(t.id)!.assignedTo, t.createdBy);
  });

  testWidgets('deleting the account signs out and removes the member', (
    tester,
  ) async {
    final store = await pumpSignedIn(tester);
    final me = store.me;
    final myTeams = store.teams.map((t) => t.id).toList();

    await openSettings(tester);
    await tester.ensureVisible(find.text('Delete account'));
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    final delete = find.widgetWithText(FilledButton, 'Delete account');
    expect(tester.widget<FilledButton>(delete).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'delete');
    await tester.pump();
    await tester.tap(delete);
    await tester.pumpAndSettle();

    expect(store.currentUser, isNull);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(store.memberByEmail(me.email), isNull);
    for (final id in myTeams) {
      expect(store.membership(id, me.id), isNull);
    }
  });

  testWidgets('the account menu only has settings and sign out', (
    tester,
  ) async {
    await pumpSignedIn(tester);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete account'), findsNothing);
    expect(find.text('Privacy policy'), findsNothing);
  });

  testWidgets('renaming in settings updates my name', (tester) async {
    final store = await pumpSignedIn(tester);
    await openSettings(tester);

    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Arun Kumar ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(store.me.fullName, 'Arun Kumar');
    expect(store.memberById(store.me.id)!.fullName, 'Arun Kumar');
    expect(find.text('Arun Kumar'), findsWidgets);
  });

  testWidgets('choosing a theme in settings applies it', (tester) async {
    final store = await pumpSignedIn(tester);
    await openSettings(tester);
    expect(store.themeMode.value, ThemeMode.system);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(store.themeMode.value, ThemeMode.dark);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Settings').first)).brightness,
      Brightness.dark,
    );
  });
}
