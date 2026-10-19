import 'package:flutter/material.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../screens/task_detail_screen.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import 'member_avatar.dart';
import 'task_badges.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.showAssignee = true,
    this.showScope = false,
  });

  final Task task;
  final bool showAssignee;
  final bool showScope;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = context.colors;
    final now = DateTime.now();
    final overdue = task.isOverdue(now);
    final due = task.dueDate;

    final chips = <Widget>[
      if (task.status == TaskStatus.inProgress)
        SoftChip(
          icon: task.status.icon,
          label: task.status.label,
          color: c.info,
          background: c.infoSoft,
        ),
      if (!task.isDone)
        SoftChip(
          icon: Icons.flag_rounded,
          label: task.priority.label,
          color: task.priority.color(c),
          background: task.priority.soft(c),
        ),
      if (due != null && !task.isDone)
        SoftChip(
          icon: Icons.calendar_today_rounded,
          label: overdue
              ? 'Overdue · ${formatDay(due, now: now)}'
              : formatDay(due, now: now),
          color: overdue
              ? c.danger
              : isSameDay(due, now)
              ? c.brand
              : c.textSecondary,
          background: overdue
              ? c.dangerSoft
              : isSameDay(due, now)
              ? c.brandSoft
              : c.surfaceMuted,
        ),
      if (task.isDone && task.completedAt != null)
        SoftChip(
          icon: Icons.done_all_rounded,
          label: 'Done ${formatDay(task.completedAt!, now: now)}',
          color: c.success,
          background: c.successSoft,
        ),
      if (showScope)
        SoftChip(
          icon: task.scope.icon,
          label: task.scope.label,
          color: c.textSecondary,
          background: c.surfaceMuted,
        ),
    ];

    final showAvatar = showAssignee && task.scope == TaskScope.common;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TaskDetailScreen(taskId: task.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusCheck(
                  status: task.status,
                  onTap: StoreScope.read(context).canChangeStatus(task)
                      ? () => StoreScope.read(context).setStatus(
                          task,
                          task.isDone ? TaskStatus.todo : TaskStatus.done,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            color: task.isDone ? c.textMuted : c.text,
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: c.textMuted,
                          ),
                        ),
                        if (task.description.isNotEmpty && !task.isDone) ...[
                          const SizedBox(height: 3),
                          Text(
                            task.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                        if (chips.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(spacing: 6, runSpacing: 6, children: chips),
                        ],
                      ],
                    ),
                  ),
                ),
                if (showAvatar) ...[
                  const SizedBox(width: 10),
                  Tooltip(
                    message:
                        store.memberById(task.assignedTo)?.fullName ??
                        'Unassigned',
                    child: MemberAvatar(
                      member: store.memberById(task.assignedTo),
                      radius: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
