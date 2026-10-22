import 'package:flutter/material.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/member_avatar.dart';
import '../widgets/task_badges.dart';
import '../widgets/ui.dart';

/// Create a task, or edit one when [taskId] is given.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    this.taskId,
    this.initialScope = TaskScope.personal,
    this.initialAssignee,
  });

  final String? taskId;
  final TaskScope initialScope;
  final String? initialAssignee;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

const _unassigned = '__unassigned__';

const _bareInput = InputDecoration(
  filled: false,
  isDense: true,
  contentPadding: EdgeInsets.zero,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
);

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late TaskScope _scope;
  late TaskPriority _priority;
  String? _assignedTo;
  DateTime? _dueDate;
  Task? _editing;
  bool _initialised = false;

  bool get _isEdit => widget.taskId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final store = StoreScope.read(context);
    final task = widget.taskId == null ? null : store.taskById(widget.taskId!);
    _editing = task;
    if (task != null) {
      _title.text = task.title;
      _description.text = task.description;
      _scope = task.scope;
      _priority = task.priority;
      _assignedTo = task.assignedTo;
      _dueDate = task.dueDate;
    } else {
      _scope = widget.initialScope;
      _priority = TaskPriority.medium;
      _assignedTo = widget.initialAssignee;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final store = StoreScope.read(context);
    final title = _title.text.trim();
    final description = _description.text.trim();
    final editing = _editing;
    if (editing != null) {
      store.updateTask(
        editing.copyWith(
          title: title,
          description: description,
          scope: _scope,
          priority: _priority,
          assignedTo: _assignedTo,
          dueDate: _dueDate,
        ),
      );
    } else {
      store.addTask(
        title: title,
        description: description,
        scope: _scope,
        priority: _priority,
        assignedTo: _assignedTo,
        dueDate: _dueDate,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = context.colors;
    final team = store.teamById(_editing?.teamId) ?? store.currentTeam!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final quickDates = [
      ('Today', today),
      ('Tomorrow', today.add(const Duration(days: 1))),
      ('Next week', today.add(const Duration(days: 7))),
    ];
    final isQuickDate =
        _dueDate != null && quickDates.any((q) => isSameDay(q.$2, _dueDate!));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEdit ? 'Edit task' : 'New task'),
            Text(
              'in ${team.name}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: c.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            // Only the creator may make a task personal: an owner looking
            // after a departed member's task keeps it common.
            if (_editing == null || _editing!.createdBy == store.me.id)
              PillToggle<TaskScope>(
                options: [
                  for (final s in TaskScope.values) (s, s.label, s.icon),
                ],
                selected: _scope,
                onChanged: (s) => setState(() => _scope = s),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                _scope == TaskScope.personal
                    ? 'A to-do for yourself. ${team.name} members can see it.'
                    : 'Shared work. Assign it to anyone in ${team.name}.',
                style: TextStyle(fontSize: 12.5, color: c.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _title,
                      autofocus: !_isEdit,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      decoration: _bareInput.copyWith(
                        hintText: 'What needs to be done?',
                        hintStyle: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: c.textMuted,
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Give the task a title'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                      decoration: _bareInput.copyWith(
                        hintText: 'Add details, links or notes…',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_scope == TaskScope.common) ...[
              const SizedBox(height: 24),
              const FieldLabel('Assign to'),
              PersonSelector(
                padding: EdgeInsets.zero,
                selected: _assignedTo ?? _unassigned,
                onSelected: (v) =>
                    setState(() => _assignedTo = v == _unassigned ? null : v),
                options: [
                  const PersonOption(
                    value: _unassigned,
                    label: 'No one',
                    icon: Icons.person_off_outlined,
                  ),
                  for (final m in store.members)
                    PersonOption(
                      value: m.id,
                      label: m.id == store.me.id ? 'Me' : m.firstName,
                      member: m,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            const FieldLabel('Priority'),
            Row(
              children: [
                for (final p in TaskPriority.values) ...[
                  if (p != TaskPriority.values.first) const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceTile(
                      icon: Icons.flag_rounded,
                      label: p.label,
                      color: p.color(c),
                      soft: p.soft(c),
                      selected: _priority == p,
                      onTap: () => setState(() => _priority = p),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            const FieldLabel('Due date'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DateChip(
                  label: 'No date',
                  selected: _dueDate == null,
                  onTap: () => setState(() => _dueDate = null),
                ),
                for (final (label, date) in quickDates)
                  _DateChip(
                    label: label,
                    selected: _dueDate != null && isSameDay(_dueDate!, date),
                    onTap: () => setState(() => _dueDate = date),
                  ),
                _DateChip(
                  icon: Icons.calendar_month_rounded,
                  label: _dueDate != null && !isQuickDate
                      ? formatDay(_dueDate!)
                      : 'Pick date',
                  selected: _dueDate != null && !isQuickDate,
                  onTap: _pickDate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.brandSoft : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? c.brand : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? c.brand : c.textSecondary,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: selected ? c.brand : c.textSecondary,
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
