import 'package:flutter/material.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/task_list.dart';
import '../widgets/team_switcher.dart';
import '../widgets/ui.dart';
import 'task_form_screen.dart';

class MyTasksScreen extends StatelessWidget {
  const MyTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final personal = store.myPersonalTasks;
    final toMe = store.assignedToMe;
    final byMe = store.assignedByMe;
    int open(List<Task> l) => l.where((t) => !t.isDone).length;

    // Everything on my plate, for the summary card.
    final mine = [...personal, ...toMe];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const TeamBar(),
              PageHeader(
                overline: formatLongDate(now),
                title: '${greeting(now)}, ${store.me.firstName}',
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SummaryCard(tasks: mine, now: now),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedTabBar(
                  tabs: [
                    ('Personal', open(personal)),
                    ('To me', open(toMe)),
                    ('By me', open(byMe)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: TabBarView(
                  children: [
                    TaskList(
                      tasks: personal,
                      emptyIcon: Icons.edit_note_rounded,
                      emptyTitle: 'No personal to-dos',
                      emptyMessage: 'Jot down anything you need to remember.',
                    ),
                    TaskList(
                      tasks: toMe,
                      showAssignee: false,
                      emptyIcon: Icons.inbox_rounded,
                      emptyTitle: 'Nothing assigned to you',
                      emptyMessage: 'Work your teammates give you shows here.',
                    ),
                    TaskList(
                      tasks: byMe,
                      emptyIcon: Icons.outbox_rounded,
                      emptyTitle: 'You haven\'t assigned anything',
                      emptyMessage: 'Hand off work to a teammate with +.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: Builder(
          builder: (context) => GradientButton(
            icon: Icons.add_rounded,
            label: 'New task',
            onPressed: () {
              // Personal tab → personal to-do; other tabs → common task.
              final tab = DefaultTabController.of(context).index;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => TaskFormScreen(
                    initialScope: tab == 0
                        ? TaskScope.personal
                        : TaskScope.common,
                    initialAssignee: tab == 1 ? store.me.id : null,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Gradient card: open count, what's due, and a completion ring.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.tasks, required this.now});

  final List<Task> tasks;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final open = tasks.where((t) => !t.isDone).length;
    final done = tasks.length - open;
    final dueToday = tasks
        .where(
          (t) => !t.isDone && t.dueDate != null && isSameDay(t.dueDate!, now),
        )
        .length;
    final overdue = tasks.where((t) => t.isOverdue(now)).length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;

    return Container(
      decoration: BoxDecoration(
        gradient: c.brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: c.brand.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative circles.
          const Positioned(
            right: -40,
            top: -50,
            child: _Circle(size: 160, opacity: 0.10),
          ),
          const Positioned(
            right: 60,
            bottom: -70,
            child: _Circle(size: 120, opacity: 0.07),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your tasks',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        open == 1 ? '1 task open' : '$open tasks open',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _GlassPill(
                            icon: Icons.today_rounded,
                            label: '$dueToday due today',
                          ),
                          if (overdue > 0)
                            _GlassPill(
                              icon: Icons.warning_amber_rounded,
                              label: '$overdue overdue',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        color: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(progress * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'done',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
