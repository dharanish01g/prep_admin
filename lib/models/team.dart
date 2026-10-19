enum TeamRole {
  owner('Owner'),
  member('Member');

  const TeamRole(this.label);
  final String label;
}

/// A separate workspace, e.g. one company. Tasks never cross teams.
class Team {
  const Team({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.joinCode,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// Index into the team logo palette.
  final int colorIndex;

  /// Short code people enter to join.
  final String joinCode;
  final String createdBy;
  final DateTime createdAt;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final w = parts.first;
      return w.substring(0, w.length < 2 ? w.length : 2).toUpperCase();
    }
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  Team copyWith({String? name, int? colorIndex, String? joinCode}) => Team(
    id: id,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
    joinCode: joinCode ?? this.joinCode,
    createdBy: createdBy,
    createdAt: createdAt,
  );
}

class TeamMembership {
  const TeamMembership({
    required this.teamId,
    required this.memberId,
    required this.role,
    required this.joinedAt,
  });

  final String teamId;
  final String memberId;
  final TeamRole role;
  final DateTime joinedAt;

  TeamMembership withRole(TeamRole role) => TeamMembership(
    teamId: teamId,
    memberId: memberId,
    role: role,
    joinedAt: joinedAt,
  );
}

/// What an invite code points to, shown before joining.
class TeamPreview {
  const TeamPreview({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.memberCount,
    required this.isMember,
  });

  final String id;
  final String name;
  final int colorIndex;
  final int memberCount;
  final bool isMember;

  String get initials => Team(
    id: id,
    name: name,
    colorIndex: colorIndex,
    joinCode: '',
    createdBy: '',
    createdAt: DateTime(2000),
  ).initials;
}
