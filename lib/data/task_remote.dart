import '../models/member.dart';
import '../models/task.dart';
import '../models/team.dart';

/// Everything the signed-in user can see.
class RemoteSnapshot {
  const RemoteSnapshot({
    required this.members,
    required this.teams,
    required this.memberships,
    required this.tasks,
  });

  final List<Member> members;
  final List<Team> teams;
  final List<TeamMembership> memberships;
  final List<Task> tasks;
}

/// The newest version published for a platform (see `app_versions`).
class AppRelease {
  const AppRelease({
    required this.version,
    required this.downloadUrl,
    required this.notes,
  });

  final String version;
  final String? downloadUrl;
  final String notes;
}

/// A failure worth showing to the user as-is.
class TaskRemoteException implements Exception {
  const TaskRemoteException(this.message, {this.offline = false});
  final String message;

  /// The server couldn't be reached (no internet), as opposed to refusing.
  final bool offline;

  @override
  String toString() => message;
}

/// The backend behind [TaskStore]. Without one the store runs on mock data.
abstract class TaskRemote {
  /// The signed-in user's id, re-emitted whenever it changes (null when
  /// signed out). Emits the restored session first.
  Stream<String?> get userIds;

  Future<void> signIn(String email, String password);

  /// True when signed in straight away; false when the server first wants
  /// the email address confirmed through a link it sent.
  Future<bool> signUp(String fullName, String email, String password);
  Future<void> signOut();

  /// Leaves every team, deletes the account and signs out.
  Future<void> deleteAccount();

  /// Renames the signed-in user; teammates see it everywhere.
  Future<void> updateName(String fullName);

  /// Null when nothing is published for [platform] ('android' or 'ios').
  Future<AppRelease?> latestRelease(String platform);

  /// Loads everything from the server and saves a copy on the device.
  Future<RemoteSnapshot> fetch();

  /// The copy saved by the last [fetch] and whose it is, so the app can open
  /// instantly, even before the backend has started; null if there is none.
  Future<({String userId, RemoteSnapshot snapshot})?> cachedSnapshot();

  /// Told after each request whether the server answered (true) or couldn't
  /// be reached (false).
  void Function(bool reachable)? onReachability;

  /// A tiny request, to find out whether the server is reachable again.
  Future<void> ping();

  /// Forgets the saved copy (signing out).
  Future<void> clearCache();

  /// Calls [onChange] whenever data the user can see changes elsewhere.
  /// Resubscribes on its own if the live connection drops.
  void listen(void Function() onChange);

  /// Told whether changes made elsewhere are arriving (true) or the live
  /// connection dropped (false) while [listen]ing.
  void Function(bool live)? onLive;
  void stopListening();

  Future<void> insertTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(String id);

  Future<Team> createTeam(String name, int colorIndex);
  Future<TeamPreview?> previewTeam(String code);
  Future<Team> joinTeam(String code);
  Future<void> updateTeam(String teamId, {String? name, int? colorIndex});
  Future<String> regenerateJoinCode(String teamId);
  Future<void> removeMember(String teamId, String memberId);
  Future<void> leaveTeam(String teamId);
}
