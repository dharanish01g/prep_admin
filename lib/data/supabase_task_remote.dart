import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member.dart';
import '../models/task.dart';
import '../models/team.dart';
import 'task_remote.dart';

/// [TaskRemote] backed by the prep-admin Supabase project. Access rules live
/// in the database (see `supabase/migrations`).
class SupabaseTaskRemote implements TaskRemote {
  SupabaseTaskRemote(this._db);

  final SupabaseClient _db;
  RealtimeChannel? _channel;

  @override
  Stream<String?> get userIds => _userIds().distinct();

  // Starts with the current session so the app never waits on an initial
  // auth event that may not come.
  Stream<String?> _userIds() async* {
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
  Future<RemoteSnapshot> fetch() => _guard(() async {
    final rows = await Future.wait([
      _db.from('profiles').select('id, full_name, email, avatar_url'),
      _db.from('ic_teams').select(),
      _db.from('ic_team_members').select(),
      _db.from('ic_tasks').select(),
    ]);
    return RemoteSnapshot(
      members: rows[0].map(_member).toList(),
      teams: rows[1].map(_team).toList(),
      memberships: rows[2].map(_membership).toList(),
      tasks: rows[3].map(_task).toList(),
    );
  });

  @override
  void listen(void Function() onChange) {
    stopListening();
    final channel = _db.channel('ic-changes');
    for (final table in ['ic_tasks', 'ic_team_members', 'ic_teams']) {
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

  /// Turns backend errors into messages fit for a snackbar.
  static Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on AuthException catch (e) {
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
      throw TaskRemoteException(e.message);
    } on TaskRemoteException {
      rethrow;
    } catch (_) {
      throw const TaskRemoteException(
        "Couldn't reach the server. Check your connection.",
      );
    }
  }
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
