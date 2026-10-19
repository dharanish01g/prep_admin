import 'package:flutter/material.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import '../widgets/member_avatar.dart';
import '../widgets/task_badges.dart';
import '../widgets/task_tile.dart';
import '../widgets/team_switcher.dart';
import '../widgets/ui.dart';
import 'task_form_screen.dart';

/// All common tasks, by status, filterable by assignee.
class TeamBoardScreen extends StatefulWidget {
  const TeamBoardScreen({super.key});

  @override
  State<TeamBoardScreen> createState() => _TeamBoardScreenState();
}

const _everyone = '__everyone__';
const _unassigned = '__unassigned__';

class _TeamBoardScreenState extends State<TeamBoardScreen> {
  /// [_everyone], [_unassigned], or a member id.
  String _filter = _everyone;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    // A person filter from another team falls back to everyone.
    final filter =
        _filter == _unassigned || store.members.any((m) => m.id == _filter)
        ? _filter
        : _everyone;
    final tasks = store.commonTasks.where((t) {
      if (filter == _everyone) return true;
      if (filter == _unassigned) return t.assignedTo == null;
      return t.assignedTo == filter;
    }).toList();
    List<Task> byStatus(TaskStatus s) =>
        tasks.where((t) => t.status == s).toList();
    final open = tasks.where((t) => !t.isDone).length;
    final overdue = tasks.where((t) => t.isOverdue(now)).length;

    return DefaultTabController(
      length: TaskStatus.values.length,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const TeamBar(),
              PageHeader(
                title: 'Board',
                subtitle: overdue > 0
                    ? '$open open · $overdue overdue'
                    : '$open open tasks',
              ),
              const SizedBox(height: 12),
              PersonSelector(
                selected: filter,
                onSelected: (v) => setState(() => _filter = v!),
                options: [
                  const PersonOption(
                    value: _everyone,
                    label: 'Everyone',
                    icon: Icons.groups_2_rounded,
                  ),
                  for (final m in store.members)
                    PersonOption(
                      value: m.id,
                      label: m.id == store.me.id ? 'Me' : m.firstName,
                      member: m,
                    ),
                  const PersonOption(
                    value: _unassigned,
                    label: 'Unassigned',
                    icon: Icons.person_off_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 840) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final s in TaskStatus.values)
                              Expanded(
                                child: _BoardColumn(
                                  status: s,
                                  tasks: byStatus(s),
                                ),
                              ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SegmentedTabBar(
                            tabs: [
                              for (final s in TaskStatus.values)
                                (s.label, byStatus(s).length),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: TabBarView(
                            children: [
                              for (final s in TaskStatus.values)
                                _StatusList(tasks: byStatus(s), status: s),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: GradientButton(
          icon: Icons.assignment_ind_rounded,
          label: 'Assign task',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => TaskFormScreen(
                initialScope: TaskScope.common,
                initialAssignee: filter == _everyone || filter == _unassigned
                    ? null
                    : filter,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusList extends StatelessWidget {
  const _StatusList({required this.tasks, required this.status});

  final List<Task> tasks;
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return EmptyState(
        icon: status.icon,
        title: 'No ${status.label.toLowerCase()} tasks',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 120),
      children: [for (final t in tasks) TaskTile(key: ValueKey(t.id), task: t)],
    );
  }
}

/// One board column on wide screens.
class _BoardColumn extends StatelessWidget {
  const _BoardColumn({required this.status, required this.tasks});

  final TaskStatus status;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.surfaceMuted.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 6),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: status.color(c),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(status.label, style: context.text.titleSmall),
                const SizedBox(width: 8),
                CountBadge(count: tasks.length, highlight: false),
              ],
            ),
          ),
          Expanded(
            child: _StatusList(tasks: tasks, status: status),
          ),
        ],
      ),
    );
  }
}
