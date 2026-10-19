import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme/app_theme.dart';

extension TaskStatusStyle on TaskStatus {
  IconData get icon => switch (this) {
    TaskStatus.todo => Icons.radio_button_unchecked_rounded,
    TaskStatus.inProgress => Icons.timelapse_rounded,
    TaskStatus.done => Icons.check_circle_rounded,
  };

  Color color(AppColors c) => switch (this) {
    TaskStatus.todo => c.brand,
    TaskStatus.inProgress => c.info,
    TaskStatus.done => c.success,
  };

  Color soft(AppColors c) => switch (this) {
    TaskStatus.todo => c.brandSoft,
    TaskStatus.inProgress => c.infoSoft,
    TaskStatus.done => c.successSoft,
  };
}

extension TaskPriorityStyle on TaskPriority {
  Color color(AppColors c) => switch (this) {
    TaskPriority.low => c.textSecondary,
    TaskPriority.medium => c.warning,
    TaskPriority.high => c.danger,
  };

  Color soft(AppColors c) => switch (this) {
    TaskPriority.low => c.surfaceMuted,
    TaskPriority.medium => c.warningSoft,
    TaskPriority.high => c.dangerSoft,
  };
}

extension TaskScopeStyle on TaskScope {
  IconData get icon => switch (this) {
    TaskScope.personal => Icons.lock_outline_rounded,
    TaskScope.common => Icons.groups_2_outlined,
  };
}

/// Tinted pill with an icon and label.
class SoftChip extends StatelessWidget {
  const SoftChip({
    super.key,
    this.icon,
    required this.label,
    required this.color,
    required this.background,
    this.large = false,
  });

  final IconData? icon;
  final String label;
  final Color color;
  final Color background;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(large ? 10 : 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: large ? 16 : 13, color: color),
            SizedBox(width: large ? 6 : 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: large ? 13 : 11.5,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small rounded counter, e.g. in tab labels.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, this.highlight = true});

  final int count;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: highlight ? c.brandSoft : c.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: highlight ? c.brand : c.textSecondary,
        ),
      ),
    );
  }
}

/// Round tick button reflecting a task's status.
class StatusCheck extends StatelessWidget {
  const StatusCheck({super.key, required this.status, required this.onTap});

  final TaskStatus status;

  /// Null when the viewer may not change the status.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = status.color(c);
    final done = status == TaskStatus.done;
    return Tooltip(
      message: onTap == null
          ? status.label
          : (done ? 'Mark as to do' : 'Mark as done'),
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? color : Colors.transparent,
              border: Border.all(
                color: status == TaskStatus.todo ? c.textMuted : color,
                width: 2,
              ),
            ),
            child: switch (status) {
              TaskStatus.done => const Icon(
                Icons.check_rounded,
                size: 16,
                color: Colors.white,
              ),
              TaskStatus.inProgress => Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              TaskStatus.todo => null,
            },
          ),
        ),
      ),
    );
  }
}

/// Selectable tile with an icon over a label (status, priority pickers).
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.soft,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color soft;
  final bool selected;

  /// Null shows the tile read-only.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            decoration: BoxDecoration(
              color: selected ? soft : c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? color : c.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: selected ? color : c.textMuted, size: 22),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? color : c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
