import 'package:flutter/material.dart';

import '../data/task_store.dart';
import '../models/member.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/member_avatar.dart';
import '../widgets/task_badges.dart';
import '../widgets/ui.dart';
import 'task_form_screen.dart';

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  Future<void> _confirmDelete(BuildContext context, Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be removed for everyone.'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    StoreScope.read(context).deleteTask(task.id);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Task deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final task = store.taskById(taskId);
    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.delete_outline_rounded,
          title: 'This task no longer exists',
        ),
      );
    }

    final c = context.colors;
    final now = DateTime.now();
    final overdue = task.isOverdue(now);

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (store.canEdit(task)) ...[
            CircleIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Edit',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => TaskFormScreen(taskId: task.id),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Delete',
              color: c.danger,
              onPressed: () => _confirmDelete(context, task),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SoftChip(
                large: true,
                icon: task.scope.icon,
                label: task.scope.label,
                color: c.brand,
                background: c.brandSoft,
              ),
              SoftChip(
                large: true,
                icon: Icons.flag_rounded,
                label: '${task.priority.label} priority',
                color: task.priority.color(c),
                background: task.priority.soft(c),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(task.title, style: context.text.headlineSmall),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              task.description,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: c.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 28),
          const FieldLabel('Status'),
          Row(
            children: [
              for (final s in TaskStatus.values) ...[
                if (s != TaskStatus.values.first) const SizedBox(width: 10),
                Expanded(
                  child: ChoiceTile(
                    icon: s.icon,
                    label: s.label,
                    color: s.color(c),
                    soft: s.soft(c),
                    selected: task.status == s,
                    onTap: store.canChangeStatus(task)
                        ? () => StoreScope.read(context).setStatus(task, s)
                        : null,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 28),
          const FieldLabel('Details'),
          Card(
            child: Column(
              children: [
                if (task.scope == TaskScope.common) ...[
                  _PersonRow(
                    label: 'Assigned to',
                    member: store.memberById(task.assignedTo),
                    isMe: task.assignedTo == store.me.id,
                  ),
                  const Divider(indent: 64),
                ],
                _PersonRow(
                  label: 'Created by',
                  member: store.memberById(task.createdBy),
                  isMe: task.createdBy == store.me.id,
                ),
                const Divider(indent: 64),
                _DetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Due date',
                  value: task.dueDate == null
                      ? 'No due date'
                      : formatDay(task.dueDate!, now: now),
                  color: overdue ? c.danger : null,
                  iconColor: overdue ? c.danger : null,
                  iconBackground: overdue ? c.dangerSoft : null,
                ),
                const Divider(indent: 64),
                _DetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Created',
                  value: formatDateTime(task.createdAt, now: now),
                ),
                const Divider(indent: 64),
                _DetailRow(
                  icon: Icons.update_rounded,
                  label: 'Updated',
                  value: formatDateTime(task.updatedAt, now: now),
                ),
                if (task.completedAt != null) ...[
                  const Divider(indent: 64),
                  _DetailRow(
                    icon: Icons.done_all_rounded,
                    label: 'Completed',
                    value: formatDateTime(task.completedAt!, now: now),
                    iconColor: c.success,
                    iconBackground: c.successSoft,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.iconColor,
    this.iconBackground,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final Color? iconColor;
  final Color? iconBackground;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          IconBadge(
            icon: icon,
            color: iconColor ?? c.textSecondary,
            background: iconBackground ?? c.surfaceMuted,
          ),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(color: c.textSecondary, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: color ?? c.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.label,
    required this.member,
    required this.isMe,
  });

  final String label;
  final Member? member;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          MemberAvatar(member: member, radius: 18),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(color: c.textSecondary, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member == null
                  ? 'Unassigned'
                  : isMe
                  ? '${member!.fullName} (you)'
                  : member!.fullName,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
