enum TaskScope {
  personal('Personal'),
  common('Common');

  const TaskScope(this.label);
  final String label;
}

enum TaskStatus {
  todo('To do'),
  inProgress('In progress'),
  done('Done');

  const TaskStatus(this.label);
  final String label;
}

enum TaskPriority {
  low('Low'),
  medium('Medium'),
  high('High');

  const TaskPriority(this.label);
  final String label;
}

const _unset = Object();

class Task {
  const Task({
    required this.id,
    required this.teamId,
    required this.title,
    this.description = '',
    this.scope = TaskScope.personal,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium,
    required this.createdBy,
    this.assignedTo,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String id;

  /// The team this task lives in. Personal to-dos belong to a team too, so
  /// nothing leaks between workspaces.
  final String teamId;
  final String title;
  final String description;
  final TaskScope scope;
  final TaskStatus status;
  final TaskPriority priority;

  /// Member ids.
  final String createdBy;
  final String? assignedTo;

  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  bool get isDone => status == TaskStatus.done;

  bool isOverdue(DateTime now) {
    final due = dueDate;
    if (due == null || isDone) return false;
    return DateTime(
      due.year,
      due.month,
      due.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
  }

  /// Nullable fields ([assignedTo], [dueDate], [completedAt]) can be cleared
  /// by passing `null` explicitly.
  Task copyWith({
    String? title,
    String? description,
    TaskScope? scope,
    TaskStatus? status,
    TaskPriority? priority,
    Object? assignedTo = _unset,
    Object? dueDate = _unset,
    DateTime? updatedAt,
    Object? completedAt = _unset,
  }) {
    return Task(
      id: id,
      teamId: teamId,
      title: title ?? this.title,
      description: description ?? this.description,
      scope: scope ?? this.scope,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdBy: createdBy,
      assignedTo: assignedTo == _unset
          ? this.assignedTo
          : assignedTo as String?,
      dueDate: dueDate == _unset ? this.dueDate : dueDate as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt == _unset
          ? this.completedAt
          : completedAt as DateTime?,
    );
  }
}
