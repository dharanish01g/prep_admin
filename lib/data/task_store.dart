import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/member.dart';
import '../models/task.dart';
import '../models/team.dart';
import '../utils/dates.dart';
import 'mock_data.dart';
import 'task_remote.dart';

/// App state, kept in memory so screens can read it synchronously.
///
/// With a [remote] it mirrors the Supabase project: task edits apply
/// instantly and sync in the background, team actions wait for the server,
/// and changes made elsewhere arrive live. Without one it runs on mock data
/// (tests, demos).
///
/// Everything task-related is scoped to [currentTeam]: switching teams swaps
/// the whole app over, so separate companies never mix.
class TaskStore extends ChangeNotifier {
  TaskStore({
    required this._members,
    required this._teams,
    required this._memberships,
    required this._tasks,
    this.remote,
  });

  factory TaskStore.mock() {
    final now = DateTime.now();
    return TaskStore(
      members: [...mockMembers],
      teams: buildMockTeams(now),
      memberships: buildMockMemberships(now),
      tasks: buildMockTasks(now),
    );
  }

  /// [watchNetwork] follows the phone's Wi-Fi/mobile state through the
  /// connectivity plugin; off where there is no Flutter app (backend tests),
  /// leaving requests alone to decide whether the app is online.
  factory TaskStore.connected(TaskRemote remote, {bool watchNetwork = true}) =>
      TaskStore(
        members: [],
        teams: [],
        memberships: [],
        tasks: [],
        remote: remote,
      ).._start(watchNetwork: watchNetwork);

  final TaskRemote? remote;
  final List<Member> _members;
  final List<Team> _teams;
  final List<TeamMembership> _memberships;
  final List<Task> _tasks;
  Member? _currentUser;
  String? _currentTeamId;
  StreamSubscription<String?>? _authSub;
  Timer? _refreshDebounce;

  /// Called with a user-facing message when a background sync fails.
  void Function(String message)? onError;

  bool get isMock => remote == null;

  /// True until the first session check (and data load) has finished.
  bool get starting => _starting;
  bool _starting = false;

  /// Still [starting] after 2 seconds: the splash shows a loading message.
  bool get slowStart => _slowStart;
  bool _slowStart = false;
  Timer? _slowStartTimer;
  bool _disposed = false;

  /// Last team each person had open (mock mode; the real app uses prefs).
  final Map<String, String> _lastTeam = {};
  int _nextId = 1;
  final _random = Random();

  Member? get currentUser => _currentUser;

  /// The signed-in member. Only valid once signed in.
  Member get me => _currentUser!;

  /// Everyone visible to the signed-in user (mock: every demo account).
  List<Member> get allMembers => List.unmodifiable(_members);

  Member? memberById(String? id) {
    if (id == null) return null;
    for (final m in _members) {
      if (m.id == id) return m;
    }
    return null;
  }

  Member? memberByEmail(String email) {
    final needle = email.trim().toLowerCase();
    for (final m in _members) {
      if (m.email.toLowerCase() == needle) return m;
    }
    return null;
  }

  // Session ------------------------------------------------------------------

  void _start({required bool watchNetwork}) {
    _starting = true;
    _slowStartTimer = Timer(const Duration(seconds: 2), () {
      if (_disposed || !_starting) return;
      _slowStart = true;
      notifyListeners();
    });
    unawaited(_loadTheme());
    remote!
      ..onReachability = _setOnline
      ..onLive = _setLive;
    if (watchNetwork) _watchNetwork();
    unawaited(_openFromCache());
  }

  /// Someone was signed in last time: show their saved tasks right away,
  /// without waiting for the backend to start. The session check that
  /// follows confirms them (and catches up) or signs them out.
  Future<void> _openFromCache() async {
    final r = remote!;
    final cached = await r.cachedSnapshot();
    if (_disposed) return;
    if (cached != null) {
      _apply(cached.snapshot);
      await _signedIn(cached.userId);
    }
    _authSub = r.userIds.listen(_onUser);
  }

  Future<void> _onUser(String? userId) async {
    final r = remote!;
    _pendingUserId = null;
    if (userId == null) {
      r.stopListening();
      _setLive(true);
      _clear();
      unawaited(r.clearCache());
      _starting = false;
      notifyListeners();
      // Nothing else talks to the server on the login screen, so check it
      // once: Wi-Fi without internet should still show the banner.
      unawaited(_retry());
      return;
    }
    if (_currentUser?.id == userId) {
      // Already showing their saved copy: catch up in the background
      // (listening also triggers a refresh once connected).
      _scheduleRefresh();
      r.listen(_scheduleRefresh);
      return;
    }
    if (_currentUser != null) _clear();
    await _loadFresh(userId);
  }

  /// First load for a user with nothing saved. Offline, it waits (on the
  /// splash or login screen, under the banner) and is retried when the
  /// connection is back.
  Future<void> _loadFresh(String userId) async {
    _pendingUserId = userId;
    try {
      await _reload();
    } on TaskRemoteException catch (e) {
      if (_disposed || e.offline) return;
      _pendingUserId = null;
      onError?.call(e.message);
      _starting = false;
      notifyListeners();
      return;
    }
    if (_disposed || _pendingUserId != userId) return;
    _pendingUserId = null;
    await _signedIn(userId);
    remote!.listen(_scheduleRefresh);
  }

  // Connection -----------------------------------------------------------------

  /// False while the server can't be reached; the app shows a banner.
  final online = ValueNotifier(true);

  /// False while teammates' changes aren't arriving live; the app says it's
  /// reconnecting. Only turns false after a few seconds, so a quick blip
  /// doesn't flash the banner.
  final live = ValueNotifier(true);
  Timer? _liveTimer;

  /// True while data is being loaded from or saved to the server; the app
  /// shows a thin progress line.
  final syncing = ValueNotifier(false);
  int _inFlight = 0;

  void _setLive(bool value) {
    if (_disposed) return;
    if (value) {
      _liveTimer?.cancel();
      _liveTimer = null;
      live.value = true;
    } else {
      _liveTimer ??= Timer(const Duration(seconds: 4), () {
        _liveTimer = null;
        if (!_disposed) live.value = false;
      });
    }
  }

  Future<T> _track<T>(Future<T> request) async {
    _inFlight++;
    syncing.value = true;
    try {
      return await request;
    } finally {
      _inFlight--;
      if (!_disposed) syncing.value = _inFlight > 0;
    }
  }

  String? _pendingUserId;
  StreamSubscription<List<ConnectivityResult>>? _networkSub;
  Timer? _retryTimer;

  void _watchNetwork() {
    final connectivity = Connectivity();
    _networkSub = connectivity.onConnectivityChanged.listen(
      _onNetwork,
      onError: (_) {},
    );
    unawaited(
      connectivity.checkConnectivity().then(_onNetwork, onError: (_) {}),
    );
  }

  void _onNetwork(List<ConnectivityResult> results) {
    if (_disposed) return;
    if (results.every((r) => r == ConnectivityResult.none)) {
      _setOnline(false);
    } else if (!online.value) {
      // A network is back, but that doesn't prove internet: try the server.
      unawaited(_retry());
    }
  }

  void _setOnline(bool value) {
    if (_disposed) return;
    online.value = value;
    if (value) {
      _retryTimer?.cancel();
      _retryTimer = null;
    } else {
      _retryTimer ??= Timer.periodic(
        const Duration(seconds: 10),
        (_) => _retry(),
      );
    }
  }

  /// Picks up where the lost connection left off.
  Future<void> _retry() async {
    final pending = _pendingUserId;
    if (pending != null) return _loadFresh(pending);
    if (_currentUser != null) return refresh();
    try {
      await remote?.ping();
    } on TaskRemoteException {
      // Still offline; the timer tries again.
    }
  }

  Future<void> _signedIn(String userId) async {
    // The profile row is created by a trigger; fall back if it's missing.
    _currentUser =
        memberById(userId) ?? Member(id: userId, fullName: '', email: '');
    _currentTeamId = await _restoreTeam(userId);
    _starting = false;
    notifyListeners();
  }

  /// Mock: any password works for a known email.
  Future<String?> signInWithEmail(String email, String password) async {
    final r = remote;
    if (r == null) {
      final m = memberByEmail(email);
      if (m == null) return 'No account for this email.';
      signIn(m);
      return null;
    }
    try {
      await r.signIn(email.trim(), password);
      return null;
    } on TaskRemoteException catch (e) {
      return e.message;
    }
  }

  Future<String?> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final r = remote;
    if (r == null) {
      if (memberByEmail(email) != null) {
        return 'An account with this email already exists.';
      }
      final m = Member(
        id: 'user-${_nextId++}',
        fullName: fullName.trim(),
        email: email.trim(),
      );
      _members.add(m);
      signIn(m);
      return null;
    }
    try {
      await r.signUp(fullName.trim(), email.trim(), password);
      return null;
    } on TaskRemoteException catch (e) {
      return e.message;
    }
  }

  /// Mock sign-in as [member].
  void signIn(Member member) {
    _currentUser = member;
    final last = _lastTeam[member.id];
    final mine = teams;
    _currentTeamId = mine.any((t) => t.id == last)
        ? last
        : (mine.isEmpty ? null : mine.first.id);
    notifyListeners();
  }

  Future<void> signOut() async {
    final r = remote;
    if (r == null) {
      _currentUser = null;
      _currentTeamId = null;
      notifyListeners();
      return;
    }
    try {
      await r.signOut();
    } on TaskRemoteException catch (e) {
      onError?.call(e.message);
    }
  }

  /// Leaves every team (as [leaveTeam] does), deletes the account and signs
  /// out. Throws [TaskRemoteException] on failure.
  Future<void> deleteAccount() async {
    final r = remote;
    if (r != null) {
      await r.deleteAccount();
      return;
    }
    for (final team in teams) {
      await leaveTeam(team.id);
    }
    _members.removeWhere((m) => m.id == me.id);
    await signOut();
  }

  /// Renames me. Throws [TaskRemoteException] on failure.
  Future<void> updateName(String fullName) async {
    final name = fullName.trim();
    if (name.isEmpty) throw const TaskRemoteException('Enter your name.');
    final r = remote;
    if (r != null) {
      await r.updateName(name);
      await _reload();
      notifyListeners();
      return;
    }
    final renamed = Member(
      id: me.id,
      fullName: name,
      email: me.email,
      avatarUrl: me.avatarUrl,
    );
    _members[_members.indexWhere((m) => m.id == me.id)] = renamed;
    _currentUser = renamed;
    notifyListeners();
  }

  /// The newest published version for [platform]; null in mock mode or when
  /// nothing is published. Throws [TaskRemoteException] on failure.
  Future<AppRelease?> latestRelease(String platform) async =>
      remote?.latestRelease(platform);

  void _clear() {
    _currentUser = null;
    _currentTeamId = null;
    _members.clear();
    _teams.clear();
    _memberships.clear();
    _tasks.clear();
  }

  Future<void> _reload() async => _apply(await _track(remote!.fetch()));

  void _apply(RemoteSnapshot s) {
    _members
      ..clear()
      ..addAll(s.members);
    _teams
      ..clear()
      ..addAll(s.teams);
    _memberships
      ..clear()
      ..addAll(s.memberships);
    _tasks
      ..clear()
      ..addAll(s.tasks);
    final userId = _currentUser?.id;
    if (userId != null) _currentUser = memberById(userId) ?? _currentUser;
    // Removed from the open team elsewhere: fall back to another one.
    if (_currentUser != null &&
        (_currentTeamId == null || !isMemberOf(_currentTeamId!))) {
      final mine = teams;
      _currentTeamId = mine.isEmpty ? null : mine.first.id;
    }
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 300), refresh);
  }

  /// Re-reads everything from the server.
  Future<void> refresh() async {
    if (remote == null || _currentUser == null) return;
    try {
      final snapshot = await _track(remote!.fetch());
      if (_disposed) return;
      _apply(snapshot);
      notifyListeners();
    } on TaskRemoteException catch (e) {
      // Offline is shown by the banner, not a snackbar per attempt.
      if (!_disposed && !e.offline) onError?.call(e.message);
    }
  }

  // Theme --------------------------------------------------------------------

  /// Light, dark or follow the phone. Kept on this device, not per account.
  final themeMode = ValueNotifier(ThemeMode.system);

  static const _themeKey = 'theme_mode';

  Future<void> _loadTheme() async {
    try {
      final name = (await SharedPreferences.getInstance()).getString(_themeKey);
      themeMode.value = ThemeMode.values.asNameMap()[name] ?? ThemeMode.system;
    } catch (_) {}
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    notifyListeners();
    if (remote == null) return;
    unawaited(_saveTheme(mode));
  }

  static Future<void> _saveTheme(ThemeMode mode) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _themeKey,
        mode.name,
      );
    } catch (_) {
      // Only a preference; the app falls back to the phone's setting.
    }
  }

  static String _prefsKey(String userId) => 'last_team_$userId';

  Future<String?> _restoreTeam(String userId) async {
    final mine = teams;
    if (mine.isEmpty) return null;
    String? last;
    try {
      last = (await SharedPreferences.getInstance()).getString(
        _prefsKey(userId),
      );
    } catch (_) {}
    return mine.any((t) => t.id == last) ? last : mine.first.id;
  }

  void _rememberTeam(String teamId) {
    _lastTeam[me.id] = teamId;
    if (remote == null) return;
    unawaited(_saveLastTeam(_prefsKey(me.id), teamId));
  }

  static Future<void> _saveLastTeam(String key, String teamId) async {
    try {
      await (await SharedPreferences.getInstance()).setString(key, teamId);
    } catch (_) {
      // Only a convenience; the app falls back to the first team.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _slowStartTimer?.cancel();
    _authSub?.cancel();
    _networkSub?.cancel();
    _retryTimer?.cancel();
    online.dispose();
    _liveTimer?.cancel();
    live.dispose();
    syncing.dispose();
    _refreshDebounce?.cancel();
    remote?.stopListening();
    themeMode.dispose();
    super.dispose();
  }

  // Teams --------------------------------------------------------------------

  /// Teams the signed-in member belongs to, oldest membership first.
  List<Team> get teams {
    final mine = _memberships.where((m) => m.memberId == me.id).toList()
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return [for (final m in mine) ?teamById(m.teamId)];
  }

  Team? get currentTeam => teamById(_currentTeamId);

  Team? teamById(String? id) {
    if (id == null) return null;
    for (final t in _teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  Team? teamByCode(String code) {
    final needle = _normaliseCode(code);
    for (final t in _teams) {
      if (t.joinCode == needle) return t;
    }
    return null;
  }

  /// Members of the current team, owner first then by join date.
  List<Member> get members {
    final team = currentTeam;
    return team == null ? const [] : membersOf(team.id);
  }

  List<Member> membersOf(String teamId) {
    final list = _memberships.where((m) => m.teamId == teamId).toList()
      ..sort((a, b) {
        if (a.role != b.role) return a.role.index.compareTo(b.role.index);
        return a.joinedAt.compareTo(b.joinedAt);
      });
    return [for (final m in list) ?memberById(m.memberId)];
  }

  TeamMembership? membership(String teamId, String memberId) {
    for (final m in _memberships) {
      if (m.teamId == teamId && m.memberId == memberId) return m;
    }
    return null;
  }

  /// "Owner" or "Member" in the current team.
  String roleLabelInTeam(String memberId) {
    final team = currentTeam;
    if (team == null) return '';
    return membership(team.id, memberId)?.role.label ?? '';
  }

  bool isOwner(String teamId, [String? memberId]) =>
      membership(teamId, memberId ?? me.id)?.role == TeamRole.owner;

  bool isMemberOf(String teamId) => membership(teamId, me.id) != null;

  void selectTeam(String teamId) {
    if (!isMemberOf(teamId)) return;
    _currentTeamId = teamId;
    _rememberTeam(teamId);
    notifyListeners();
  }

  /// My open tasks in [teamId] (assigned to me, personal included).
  int myOpenCountIn(String teamId) => _tasks
      .where((t) => t.teamId == teamId && t.assignedTo == me.id && !t.isDone)
      .length;

  /// My open tasks in [teamId] that are overdue or due today.
  int myUrgentCountIn(String teamId, {DateTime? now}) {
    final today = now ?? DateTime.now();
    return _tasks
        .where(
          (t) =>
              t.teamId == teamId &&
              t.assignedTo == me.id &&
              !t.isDone &&
              t.dueDate != null &&
              (t.isOverdue(today) || isSameDay(t.dueDate!, today)),
        )
        .length;
  }

  /// Whether a team other than the current one has something urgent for me.
  bool get hasUrgentElsewhere =>
      teams.any((t) => t.id != _currentTeamId && myUrgentCountIn(t.id) > 0);

  /// Creates a team with me as owner and switches to it. Throws
  /// [TaskRemoteException] on failure.
  Future<Team> createTeam({
    required String name,
    required int colorIndex,
  }) async {
    final r = remote;
    if (r != null) {
      final team = await r.createTeam(name.trim(), colorIndex);
      await _reload();
      selectTeam(team.id);
      return teamById(team.id) ?? team;
    }
    final now = DateTime.now();
    final team = Team(
      id: 'team-${_nextId++}',
      name: name.trim(),
      colorIndex: colorIndex,
      joinCode: _newCode(),
      createdBy: me.id,
      createdAt: now,
    );
    _teams.add(team);
    _memberships.add(
      TeamMembership(
        teamId: team.id,
        memberId: me.id,
        role: TeamRole.owner,
        joinedAt: now,
      ),
    );
    selectTeam(team.id);
    return team;
  }

  /// The team an invite code points to, or null if none.
  Future<TeamPreview?> previewTeam(String code) async {
    final r = remote;
    if (r != null) return r.previewTeam(code);
    final team = teamByCode(code);
    if (team == null) return null;
    return TeamPreview(
      id: team.id,
      name: team.name,
      colorIndex: team.colorIndex,
      memberCount: membersOf(team.id).length,
      isMember: isMemberOf(team.id),
    );
  }

  /// Joins the team for [code] (no-op if already in it) and switches to it.
  Future<Team> joinTeam(String code) async {
    final r = remote;
    if (r != null) {
      final team = await r.joinTeam(code);
      await _reload();
      selectTeam(team.id);
      return teamById(team.id) ?? team;
    }
    final team = teamByCode(code);
    if (team == null) throw const TaskRemoteException('No team uses this code');
    if (!isMemberOf(team.id)) {
      _memberships.add(
        TeamMembership(
          teamId: team.id,
          memberId: me.id,
          role: TeamRole.member,
          joinedAt: DateTime.now(),
        ),
      );
    }
    selectTeam(team.id);
    return team;
  }

  Future<void> updateTeam(
    String teamId, {
    String? name,
    int? colorIndex,
  }) async {
    if (!isOwner(teamId)) return;
    final r = remote;
    if (r != null) {
      await r.updateTeam(teamId, name: name?.trim(), colorIndex: colorIndex);
      await _reload();
      notifyListeners();
      return;
    }
    final i = _teams.indexWhere((t) => t.id == teamId);
    if (i == -1) return;
    _teams[i] = _teams[i].copyWith(name: name?.trim(), colorIndex: colorIndex);
    notifyListeners();
  }

  /// Makes a new invite code; the old one stops working.
  Future<void> regenerateJoinCode(String teamId) async {
    if (!isOwner(teamId)) return;
    final r = remote;
    if (r != null) {
      await r.regenerateJoinCode(teamId);
      await _reload();
      notifyListeners();
      return;
    }
    final i = _teams.indexWhere((t) => t.id == teamId);
    if (i == -1) return;
    _teams[i] = _teams[i].copyWith(joinCode: _newCode());
    notifyListeners();
  }

  /// Owner only. Their personal to-dos in the team go, and their common
  /// tasks become unassigned.
  Future<void> removeMember(String teamId, String memberId) async {
    if (!isOwner(teamId) || memberId == me.id) return;
    final r = remote;
    if (r != null) {
      await r.removeMember(teamId, memberId);
      await _reload();
      notifyListeners();
      return;
    }
    _dropMember(teamId, memberId);
    notifyListeners();
  }

  /// If the owner leaves, the longest-standing member takes over. The last
  /// person out deletes the team.
  Future<void> leaveTeam(String teamId) async {
    final r = remote;
    if (r != null) {
      await r.leaveTeam(teamId);
      await _reload();
      notifyListeners();
      return;
    }
    final wasOwner = isOwner(teamId);
    _dropMember(teamId, me.id);
    final rest = _memberships.where((m) => m.teamId == teamId).toList()
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    if (rest.isEmpty) {
      _teams.removeWhere((t) => t.id == teamId);
      _tasks.removeWhere((t) => t.teamId == teamId);
    } else if (wasOwner) {
      final i = _memberships.indexOf(rest.first);
      _memberships[i] = rest.first.withRole(TeamRole.owner);
    }
    if (_currentTeamId == teamId) {
      final mine = teams;
      _currentTeamId = mine.isEmpty ? null : mine.first.id;
      if (_currentTeamId != null) _lastTeam[me.id] = _currentTeamId!;
    }
    notifyListeners();
  }

  void _dropMember(String teamId, String memberId) {
    _memberships.removeWhere(
      (m) => m.teamId == teamId && m.memberId == memberId,
    );
    _tasks.removeWhere(
      (t) =>
          t.teamId == teamId &&
          t.scope == TaskScope.personal &&
          t.createdBy == memberId,
    );
    for (var i = 0; i < _tasks.length; i++) {
      final t = _tasks[i];
      if (t.teamId == teamId && t.assignedTo == memberId) {
        _tasks[i] = t.copyWith(assignedTo: null);
      }
    }
  }

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _newCode() {
    String code;
    do {
      code = String.fromCharCodes(
        List.generate(
          6,
          (_) => _codeChars.codeUnitAt(_random.nextInt(_codeChars.length)),
        ),
      );
    } while (teamByCode(code) != null);
    return code;
  }

  static String _normaliseCode(String code) =>
      code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  // Tasks (current team only) ------------------------------------------------

  Iterable<Task> get _teamTasks {
    final id = _currentTeamId;
    return id == null ? const [] : _tasks.where((t) => t.teamId == id);
  }

  Task? taskById(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<Task> get myPersonalTasks => _sorted(
    _teamTasks.where(
      (t) => t.scope == TaskScope.personal && t.createdBy == me.id,
    ),
  );

  List<Task> get assignedToMe => _sorted(
    _teamTasks.where(
      (t) => t.scope == TaskScope.common && t.assignedTo == me.id,
    ),
  );

  List<Task> get assignedByMe => _sorted(
    _teamTasks.where(
      (t) =>
          t.scope == TaskScope.common &&
          t.createdBy == me.id &&
          t.assignedTo != me.id,
    ),
  );

  List<Task> get commonTasks =>
      _sorted(_teamTasks.where((t) => t.scope == TaskScope.common));

  /// Everything on a member's plate in this team: tasks assigned to them
  /// plus their own personal to-dos.
  List<Task> tasksFor(String memberId) =>
      _sorted(_teamTasks.where((t) => t.assignedTo == memberId));

  Task addTask({
    required String title,
    String description = '',
    required TaskScope scope,
    TaskPriority priority = TaskPriority.medium,
    String? assignedTo,
    DateTime? dueDate,
  }) {
    final now = DateTime.now();
    final task = Task(
      // Ids are made here so the task can be shown before the server answers.
      id: remote == null ? 'new-${_nextId++}' : _uuid(),
      teamId: currentTeam!.id,
      title: title,
      description: description,
      scope: scope,
      priority: priority,
      createdBy: me.id,
      assignedTo: scope == TaskScope.personal ? me.id : assignedTo,
      dueDate: dueDate,
      createdAt: now,
      updatedAt: now,
    );
    _tasks.add(task);
    notifyListeners();
    _sync((r) => r.insertTask(task));
    return task;
  }

  /// The creator edits or deletes a task. Once they've left the team (or
  /// deleted their account), the team owner looks after it instead.
  bool canEdit(Task task) =>
      task.createdBy == me.id ||
      (isOwner(task.teamId) && membership(task.teamId, task.createdBy) == null);

  /// The creator and the assignee can move a task between statuses.
  bool canChangeStatus(Task task) => canEdit(task) || task.assignedTo == me.id;

  void updateTask(Task updated) {
    final index = _tasks.indexWhere((t) => t.id == updated.id);
    if (index == -1) return;
    final old = _tasks[index];
    final now = DateTime.now();

    DateTime? completedAt = updated.completedAt;
    if (updated.isDone && !old.isDone) completedAt = now;
    if (!updated.isDone) completedAt = null;

    final task = updated.copyWith(
      // Personal to-dos always belong to whoever created them.
      assignedTo: updated.scope == TaskScope.personal
          ? updated.createdBy
          : updated.assignedTo,
      updatedAt: now,
      completedAt: completedAt,
    );
    _tasks[index] = task;
    notifyListeners();
    _sync((r) => r.updateTask(task));
  }

  void setStatus(Task task, TaskStatus status) =>
      updateTask(task.copyWith(status: status));

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    _sync((r) => r.deleteTask(id));
  }

  /// Sends a change that's already applied locally; on failure, says so and
  /// reloads the server's version.
  void _sync(Future<void> Function(TaskRemote r) op) {
    final r = remote;
    if (r == null) return;
    _track(op(r)).catchError((Object e) {
      onError?.call(switch (e) {
        TaskRemoteException(offline: true) =>
          "You're offline, so that change wasn't saved.",
        TaskRemoteException(:final message) => message,
        _ => "Couldn't save that change.",
      });
      refresh();
    });
  }

  String _uuid() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// Open before done, then by due date (soonest first, none last), then
  /// priority, then newest.
  List<Task> _sorted(Iterable<Task> tasks) {
    final list = tasks.toList();
    list.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      if (a.isDone) {
        return (b.completedAt ?? b.updatedAt).compareTo(
          a.completedAt ?? a.updatedAt,
        );
      }
      final ad = a.dueDate, bd = b.dueDate;
      if (ad != bd) {
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      }
      if (a.priority != b.priority) {
        return b.priority.index.compareTo(a.priority.index);
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }
}

/// Makes the [TaskStore] available to the widget tree and rebuilds
/// dependents when it changes.
class StoreScope extends InheritedNotifier<TaskStore> {
  const StoreScope({super.key, required TaskStore store, required super.child})
    : super(notifier: store);

  /// Reads the store and rebuilds the caller when it changes.
  static TaskStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Reads the store without subscribing (for callbacks).
  static TaskStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
