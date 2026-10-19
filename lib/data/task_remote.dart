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

/// A failure worth showing to the user as-is.
class TaskRemoteException implements Exception {
  const TaskRemoteException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The backend behind [TaskStore]. Without one the store runs on mock data.
abstract class TaskRemote {
  /// The signed-in user's id, re-emitted whenever it changes (null when
  /// signed out). Emits the restored session first.
  Stream<String?> get userIds;

  Future<void> signIn(String email, String password);
  Future<void> signUp(String fullName, String email, String password);
  Future<void> signOut();

  Future<RemoteSnapshot> fetch();

  /// Calls [onChange] whenever data the user can see changes elsewhere.
  void listen(void Function() onChange);
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
