import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models/member.dart';
import '../models/task.dart';
import '../models/team.dart';
import 'task_remote.dart';

/// [TaskRemote] backed by the prep-admin Supabase project. Access rules live
/// in the database (see `supabase/migrations`).
class SupabaseTaskRemote implements TaskRemote {
  /// Uses a client that is already set up (tests).
  SupabaseTaskRemote(SupabaseClient db) : _ready = Future.value(db) {
    _client = db;
  }

  /// Starts Supabase in the background so the app can draw its first screen
  /// straight away. Requests made before it's ready wait for it.
  SupabaseTaskRemote.initialize()
    : _ready = Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublishableKey,
        // Records each request as a breadcrumb and reports 5xx answers.
        httpClient: SentryHttpClient(),
      ).then((s) => s.client) {
    // Registered before any request can await [_ready], so [_db] is set by
    // the time they resume.
    _ready.then((c) => _client = c, onError: (_) {});
  }

  final Future<SupabaseClient> _ready;
  SupabaseClient? _client;
  SupabaseClient get _db => _client!;
  RealtimeChannel? _channel;

  @override
  void Function(bool reachable)? onReachability;

  @override
  Stream<String?> get userIds => _userIds().distinct();

  // Starts with the current session so the app never waits on an initial
  // auth event that may not come.
  Stream<String?> _userIds() async* {
    await _ready;
    yield _db.auth.currentUser?.id;
    yield* _db.auth.onAuthStateChange.map((s) => s.session?.user.id);
  }

  @override
  Future<void> signIn(String email, String password) => _guard(
    () => _db.auth.signInWithPassword(email: email, password: password),
  );

  @override
  Future<void> signUp(String fullName, String email, String password) => _guard(
    () => _db.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    ),
  );

  @override
  Future<void> signOut() => _guard(() => _db.auth.signOut());

  // The login is gone (and its sessions with it), so only the local session
  // is left to clear.
  @override
  Future<void> deleteAccount() => _guard(() async {
    await _db.rpc<void>('ic_delete_account');
    await _db.auth.signOut(scope: SignOutScope.local);
  });

  @override
  Future<void> updateName(String fullName) => _guard(
    () => _db
        .from('profiles')
        .update({'full_name': fullName})
        .eq('id', _db.auth.currentUser!.id),
  );

  @override
  Future<AppRelease?> latestRelease(String platform) => _guard(() async {
    final r = await _db
        .from('app_versions')
        .select('latest_version, download_url, notes')
        .eq('platform', platform)
        .maybeSingle();
    if (r == null) return null;
    return AppRelease(
      version: r['latest_version'] as String,
      downloadUrl: r['download_url'] as String?,
      notes: r['notes'] as String? ?? '',
    );
  });

  @override
  Future<RemoteSnapshot> fetch() => _guard(() async {
    final userId = _db.auth.currentUser?.id;
    final rows = await Future.wait([
      _db.from('profiles').select('id, full_name, email, avatar_url'),
      _db.from('ic_teams').select(),
      _db.from('ic_team_members').select(),
      _db.from('ic_tasks').select(),
    ]);
    if (userId != null) unawaited(_saveCache(userId, rows));
    return _snapshot(rows);
  });

  static const _cacheKey = 'snapshot_cache';

  static RemoteSnapshot _snapshot(List<List<Map<String, dynamic>>> rows) =>
      RemoteSnapshot(
        members: rows[0].map(_member).toList(),
        teams: rows[1].map(_team).toList(),
        memberships: rows[2].map(_membership).toList(),
        tasks: rows[3].map(_task).toList(),
      );

  Future<void> _saveCache(
    String userId,
    List<List<Map<String, dynamic>>> rows,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Signed out (or switched user) while loading: don't keep their data.
      if (_db.auth.currentUser?.id != userId) return;
      await prefs.setString(
        _cacheKey,
        jsonEncode({'user': userId, 'rows': rows}),
      );
    } catch (_) {
      // Only speeds up the next launch.
    }
  }

  @override
  Future<({String userId, RemoteSnapshot snapshot})?> cachedSnapshot() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final snapshot = _snapshot([
        for (final table in json['rows'] as List<dynamic>)
          [for (final r in table as List<dynamic>) r as Map<String, dynamic>],
      ]);
      return (userId: json['user'] as String, snapshot: snapshot);
    } catch (e, stack) {
      // Unreadable (e.g. saved by an older version): load from the server.
      unawaited(Sentry.captureException(e, stackTrace: stack));
      return null;
    }
  }

  @override
  Future<void> ping() =>
      _guard(() => _db.from('app_versions').select('platform').limit(1));

  @override
  Future<void> clearCache() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_cacheKey);
    } catch (_) {}
  }

  @override
  void listen(void Function() onChange) {
    stopListening();
    final channel = _db.channel('ic-changes');
    for (final table in [
      'ic_tasks',
      'ic_team_members',
      'ic_teams',
      'profiles',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => onChange(),
      );
    }
    // Changes made while the socket was down (app in background, phone
    // asleep, or before this first subscribe) are never replayed, so catch
    // up every time it (re)connects.
    _channel = channel
      ..subscribe((status, _) {
        if (status == RealtimeSubscribeStatus.subscribed) onChange();
      });
  }

  @override
  void stopListening() {
    final channel = _channel;
    _channel = null;
    if (channel != null) _db.removeChannel(channel);
  }

  @override
  Future<void> insertTask(Task task) => _guard(
    () => _db.from('ic_tasks').insert({'id': task.id, ..._taskRow(task)}),
  );

  @override
  Future<void> updateTask(Task task) => _guard(
    () => _db.from('ic_tasks').update(_taskRow(task)).eq('id', task.id),
  );

  @override
  Future<void> deleteTask(String id) =>
      _guard(() => _db.from('ic_tasks').delete().eq('id', id));

  @override
  Future<Team> createTeam(String name, int colorIndex) => _guard(() async {
    final row = await _db.rpc<Map<String, dynamic>>(
      'ic_create_team',
      params: {'p_name': name, 'p_color': colorIndex},
    );
    return _team(row);
  });

  @override
  Future<TeamPreview?> previewTeam(String code) => _guard(() async {
    final rows = await _db.rpc<List<dynamic>>(
      'ic_preview_team',
      params: {'p_code': code},
    );
    if (rows.isEmpty) return null;
    final r = rows.first as Map<String, dynamic>;
    return TeamPreview(
      id: r['id'] as String,
      name: r['name'] as String,
      colorIndex: r['color'] as int,
      memberCount: r['member_count'] as int,
      isMember: r['is_member'] as bool,
    );
  });

  @override
  Future<Team> joinTeam(String code) => _guard(() async {
    final row = await _db.rpc<Map<String, dynamic>>(
      'ic_join_team',
      params: {'p_code': code},
    );
    return _team(row);
  });

  @override
  Future<void> updateTeam(String teamId, {String? name, int? colorIndex}) =>
      _guard(
        () => _db
            .from('ic_teams')
            .update({'name': ?name, 'color': ?colorIndex})
            .eq('id', teamId),
      );

  @override
  Future<String> regenerateJoinCode(String teamId) => _guard(
    () =>
        _db.rpc<String>('ic_regenerate_join_code', params: {'p_team': teamId}),
  );

  @override
  Future<void> removeMember(String teamId, String memberId) => _guard(
    () => _db.rpc<void>(
      'ic_remove_member',
      params: {'p_team': teamId, 'p_user': memberId},
    ),
  );

  @override
  Future<void> leaveTeam(String teamId) =>
      _guard(() => _db.rpc<void>('ic_leave_team', params: {'p_team': teamId}));

  /// Waits for Supabase to start, reports whether the server answered, and
  /// turns backend errors into messages fit for a snackbar.
  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      await _ready;
      final result = await op();
      onReachability?.call(true);
      return result;
    } on AuthRetryableFetchException {
      onReachability?.call(false);
      throw _offline;
    } on AuthException catch (e) {
      onReachability?.call(true);
      throw TaskRemoteException(switch (e.code) {
        'invalid_credentials' => 'Wrong email or password.',
        'user_already_exists' ||
        'email_exists' => 'An account with this email already exists.',
        'weak_password' => 'Choose a stronger password (8+ characters).',
        'email_address_invalid' => 'Enter a valid email address.',
        'over_request_rate_limit' ||
        'over_email_send_rate_limit' => 'Too many attempts. Try again soon.',
        _ => e.message,
      });
    } on PostgrestException catch (e) {
      onReachability?.call(true);
      throw TaskRemoteException(e.message);
    } on TaskRemoteException {
      rethrow;
    } catch (e, stack) {
      // Losing the connection is expected; anything else is a bug worth
      // seeing, even though the user is told they're offline.
      if (e is! SocketException &&
          e is! ClientException &&
          e is! TimeoutException) {
        unawaited(Sentry.captureException(e, stackTrace: stack));
      }
      onReachability?.call(false);
      throw _offline;
    }
  }

  static const _offline = TaskRemoteException(
    "Couldn't reach the server. Check your connection.",
    offline: true,
  );
}

// Row mapping ------------------------------------------------------------------

Member _member(Map<String, dynamic> r) => Member(
  id: r['id'] as String,
  fullName: r['full_name'] as String? ?? '',
  email: r['email'] as String? ?? '',
  avatarUrl: r['avatar_url'] as String?,
);

Team _team(Map<String, dynamic> r) => Team(
  id: r['id'] as String,
  name: r['name'] as String,
  colorIndex: r['color'] as int,
  joinCode: r['join_code'] as String,
  createdBy: r['created_by'] as String? ?? '',
  createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
);

TeamMembership _membership(Map<String, dynamic> r) => TeamMembership(
  teamId: r['team_id'] as String,
  memberId: r['user_id'] as String,
  role: r['role'] == 'owner' ? TeamRole.owner : TeamRole.member,
  joinedAt: DateTime.parse(r['joined_at'] as String).toLocal(),
);

const _statusNames = {
  TaskStatus.todo: 'todo',
  TaskStatus.inProgress: 'in_progress',
  TaskStatus.done: 'done',
};

DateTime? _time(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();

Task _task(Map<String, dynamic> r) => Task(
  id: r['id'] as String,
  teamId: r['team_id'] as String,
  title: r['title'] as String,
  description: r['description'] as String? ?? '',
  scope: TaskScope.values.byName(r['scope'] as String),
  status: _statusNames.entries.firstWhere((e) => e.value == r['status']).key,
  priority: TaskPriority.values.byName(r['priority'] as String),
  createdBy: r['created_by'] as String? ?? '',
  assignedTo: r['assigned_to'] as String?,
  // A plain date: parse as local midnight.
  dueDate: r['due_date'] == null
      ? null
      : DateTime.parse(r['due_date'] as String),
  createdAt: _time(r['created_at'])!,
  updatedAt: _time(r['updated_at'])!,
  completedAt: _time(r['completed_at']),
);

Map<String, dynamic> _taskRow(Task t) {
  final due = t.dueDate;
  return {
    'team_id': t.teamId,
    'title': t.title,
    'description': t.description,
    'scope': t.scope.name,
    'status': _statusNames[t.status],
    'priority': t.priority.name,
    'assigned_to': t.assignedTo,
    'due_date': due == null
        ? null
        : '${due.year.toString().padLeft(4, '0')}-'
              '${due.month.toString().padLeft(2, '0')}-'
              '${due.day.toString().padLeft(2, '0')}',
  };
}
