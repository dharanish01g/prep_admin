import 'package:flutter/material.dart';

import '../data/task_remote.dart';
import '../data/task_store.dart';
import '../models/member.dart';
import '../models/team.dart';
import '../theme/app_theme.dart';
import '../widgets/member_avatar.dart';
import '../widgets/task_badges.dart';
import '../widgets/team_switcher.dart';
import '../widgets/ui.dart';
import 'team_setup_screen.dart';

class TeamSettingsScreen extends StatelessWidget {
  const TeamSettingsScreen({super.key, required this.teamId});

  final String teamId;

  Future<void> _confirmRemove(BuildContext context, Team team, Member m) async {
    final ok = await _confirm(
      context,
      title: 'Remove ${m.firstName}?',
      message:
          '${m.fullName} will lose access to ${team.name}. Tasks assigned to '
          'them become unassigned, and their personal to-dos here are deleted.',
      action: 'Remove',
    );
    if (!ok || !context.mounted) return;
    try {
      await StoreScope.read(context).removeMember(team.id, m.id);
    } on TaskRemoteException catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _confirmLeave(BuildContext context, Team team) async {
    final store = StoreScope.read(context);
    final others = store
        .membersOf(team.id)
        .where((m) => m.id != store.me.id)
        .toList();
    final String message;
    if (others.isEmpty) {
      message =
          "You're the only member. Leaving deletes ${team.name} and all of "
          'its tasks.';
    } else {
      final heir = store.isOwner(team.id)
          ? ' Ownership passes to ${_longestMember(store, team.id).fullName}.'
          : '';
      message =
          'Your personal to-dos in ${team.name} are deleted and tasks '
          'assigned to you become unassigned.$heir';
    }
    final ok = await _confirm(
      context,
      title: others.isEmpty ? 'Leave and delete team?' : 'Leave ${team.name}?',
      message: message,
      action: others.isEmpty ? 'Delete team' : 'Leave',
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await store.leaveTeam(team.id);
    } on TaskRemoteException catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
      return;
    }
    navigator.popUntil((r) => r.isFirst);
    messenger.showSnackBar(SnackBar(content: Text('You left ${team.name}')));
  }

  /// Who'd take over if the owner left: earliest joiner other than me.
  static Member _longestMember(TaskStore store, String teamId) {
    final others =
        store
            .membersOf(teamId)
            .where((m) => m.id != store.me.id)
            .map((m) => store.membership(teamId, m.id)!)
            .toList()
          ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return store.memberById(others.first.memberId)!;
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = context.colors;
    final team = store.teamById(teamId);
    if (team == null || !store.isMemberOf(teamId)) {
      return Scaffold(appBar: AppBar());
    }
    final owner = store.isOwner(team.id);
    final members = store.membersOf(team.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team settings'),
        actions: [
          if (owner)
            CircleIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Edit team',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => TeamFormScreen(teamId: team.id),
                ),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Row(
            children: [
              TeamLogo.of(team, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(team.name, style: context.text.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '${members.length} '
                      '${members.length == 1 ? 'member' : 'members'}'
                      ' · You are ${owner ? 'the owner' : 'a member'}',
                      style: TextStyle(color: c.textSecondary, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const FieldLabel('Invite people'),
          InviteCodeCard(team: team, canRegenerate: owner),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Anyone with this code can join straight away.',
              style: TextStyle(fontSize: 12.5, color: c.textMuted),
            ),
          ),
          const SizedBox(height: 24),
          FieldLabel('Members (${members.length})'),
          Card(
            child: Column(
              children: [
                for (final m in members) ...[
                  if (m != members.first) const Divider(indent: 66),
                  _MemberRow(
                    member: m,
                    role: store.membership(team.id, m.id)!.role,
                    isMe: m.id == store.me.id,
                    onRemove: owner && m.id != store.me.id
                        ? () => _confirmRemove(context, team, m)
                        : null,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => _confirmLeave(context, team),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.danger,
              side: BorderSide(color: c.danger.withValues(alpha: 0.4)),
            ),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: Text('Leave ${team.name}'),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.role,
    required this.isMe,
    this.onRemove,
  });

  final Member member;
  final TeamRole role;
  final bool isMe;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 10, onRemove == null ? 14 : 4, 10),
      child: Row(
        children: [
          MemberAvatar(member: member, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${member.fullName} (you)' : member.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                Text(
                  member.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                ),
              ],
            ),
          ),
          if (role == TeamRole.owner)
            SoftChip(
              icon: Icons.star_rounded,
              label: role.label,
              color: c.warning,
              background: c.warningSoft,
            ),
          if (onRemove != null)
            PopupMenuButton<void>(
              tooltip: 'Member options',
              icon: Icon(Icons.more_vert_rounded, color: c.textMuted),
              itemBuilder: (_) => [
                PopupMenuItem<void>(
                  onTap: onRemove,
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_remove_outlined,
                        size: 20,
                        color: c.danger,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Remove from team',
                        style: TextStyle(
                          color: c.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
