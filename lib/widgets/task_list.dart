import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme/app_theme.dart';
import 'task_badges.dart';
import 'task_tile.dart';
import 'ui.dart';

/// Open tasks, followed by a collapsible "Completed" section.
class TaskList extends StatefulWidget {
  const TaskList({
    super.key,
    required this.tasks,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptyMessage,
    this.showAssignee = true,
    this.showScope = false,
  });

  final List<Task> tasks;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final bool showAssignee;
  final bool showScope;

  @override
  State<TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<TaskList> {
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) {
      return EmptyState(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
      );
    }
    final c = context.colors;
    final open = widget.tasks.where((t) => !t.isDone).toList();
    final done = widget.tasks.where((t) => t.isDone).toList();

    Widget tile(Task t) => TaskTile(
      key: ValueKey(t.id),
      task: t,
      showAssignee: widget.showAssignee,
      showScope: widget.showScope,
    );

    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 120),
      children: [
        if (open.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.successSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.celebration_rounded, color: c.success),
                  const SizedBox(width: 12),
                  Text(
                    'All caught up!',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ...open.map(tile),
        if (done.isNotEmpty) ...[
          InkWell(
            onTap: () => setState(() => _showCompleted = !_showCompleted),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 20, 10),
              child: Row(
                children: [
                  Text(
                    'Completed',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CountBadge(count: done.length, highlight: false),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _showCompleted ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showCompleted) ...done.map(tile),
        ],
      ],
    );
  }
}
