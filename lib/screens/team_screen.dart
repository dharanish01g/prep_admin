import 'package:flutter/material.dart';

import '../data/task_store.dart';
import '../models/member.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import '../widgets/member_avatar.dart';
import '../widgets/task_badges.dart';
import '../widgets/task_list.dart';
import '../widgets/team_switcher.dart';
import '../widgets/ui.dart';
import 'task_form_screen.dart';
import 'team_settings_screen.dart';
import 'team_setup_screen.dart';

/// Everyone's workload at a glance.
class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = context.colors;
    final now = DateTime.now();
    final team = store.currentTeam!;
    final all = [for (final m in store.members) ...store.tasksFor(m.id)];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const TeamBar(),
            PageHeader(
              title: 'Team',
              subtitle: '${store.members.length} members',
              trailing: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleIconButton(
                      icon: Icons.person_add_alt_rounded,
                      tooltip: 'Invite people',
                      onPressed: () => showInviteSheet(context, team),
                    ),
                    const SizedBox(width: 8),
                    CircleIconButton(
                      icon: Icons.settings_outlined,
                      tooltip: 'Team settings',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TeamSettingsScreen(teamId: team.id),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.pending_actions_rounded,
                      value: all.where((t) => !t.isDone).length,
                      label: 'Open',
                      color: c.brand,
                      soft: c.brandSoft,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.timelapse_rounded,
                      value: all
                          .where((t) => t.status == TaskStatus.inProgress)
                          .length,
                      label: 'In progress',
                      color: c.info,
                      soft: c.infoSoft,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.warning_amber_rounded,
                      value: all.where((t) => t.isOverdue(now)).length,
                      label: 'Overdue',
                      color: c.danger,
                      soft: c.dangerSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: FieldLabel('Members'),
            ),
            for (final m in store.members)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _MemberCard(
                  member: m,
                  tasks: store.tasksFor(m.id),
                  isMe: m.id == store.me.id,
                  now: now,
                ),
              ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: FieldLabel('Invite people'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InviteCodeCard(team: team),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.soft,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, color: color, background: soft, size: 34),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.tasks,
    required this.isMe,
    required this.now,
  });

  final Member member;
  final List<Task> tasks;
  final bool isMe;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final open = tasks.where((t) => !t.isDone).length;
    final done = tasks.length - open;
    final overdue = tasks.where((t) => t.isOverdue(now)).length;

    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MemberTasksScreen(member: member),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              MemberAvatar(member: member, radius: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          SoftChip(
                            label: 'You',
                            color: c.brand,
                            background: c.brandSoft,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      StoreScope.of(context).roleLabelInTeam(member.id),
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: tasks.isEmpty ? 0 : done / tasks.length,
                        minHeight: 6,
                        color: c.brand,
                        backgroundColor: c.surfaceMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '$done of ${tasks.length} done',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.textMuted,
                          ),
                        ),
                        if (overdue > 0) ...[
                          const SizedBox(width: 8),
                          SoftChip(
                            label: '$overdue overdue',
                            color: c.danger,
                            background: c.dangerSoft,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Text(
                    '$open',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'open',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MemberTasksScreen extends StatelessWidget {
  const MemberTasksScreen({super.key, required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = context.colors;
    final tasks = store.tasksFor(member.id);
    final open = tasks.where((t) => !t.isDone).length;
    final inProgress = tasks
        .where((t) => t.status == TaskStatus.inProgress)
        .length;

    return Scaffold(
      appBar: AppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                MemberAvatar(member: member, radius: 30),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.fullName, style: context.text.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        store.roleLabelInTeam(member.id),
                        style: TextStyle(color: c.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          SoftChip(
                            label: '$open open',
                            color: c.brand,
                            background: c.brandSoft,
                          ),
                          SoftChip(
                            label: '$inProgress in progress',
                            color: c.info,
                            background: c.infoSoft,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TaskList(
              tasks: tasks,
              showAssignee: false,
              showScope: true,
              emptyIcon: Icons.inbox_rounded,
              emptyTitle: '${member.firstName} has no tasks',
              emptyMessage: 'Assign something to get them started.',
            ),
          ),
        ],
      ),
      floatingActionButton: GradientButton(
        icon: Icons.assignment_ind_rounded,
        label: 'Assign to ${member.firstName}',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => TaskFormScreen(
              initialScope: TaskScope.common,
              initialAssignee: member.id,
            ),
          ),
        ),
      ),
    );
  }
}
