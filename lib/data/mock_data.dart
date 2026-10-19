import '../models/member.dart';
import '../models/task.dart';
import '../models/team.dart';

/// Sample people for building the UI. Replaced by prepwisely profiles later.
const mockMembers = [
  Member(id: 'm1', fullName: 'Arun Kumar', email: 'arun@team.test'),
  Member(id: 'm2', fullName: 'Priya Shankar', email: 'priya@team.test'),
  Member(id: 'm3', fullName: 'Karthik Raja', email: 'karthik@team.test'),
  Member(id: 'm4', fullName: 'Meena Venkat', email: 'meena@team.test'),
  Member(id: 'm5', fullName: 'Rahul Nair', email: 'rahul@team.test'),
  Member(id: 'm6', fullName: 'Divya Ramesh', email: 'divya@team.test'),
  Member(id: 'm7', fullName: 'Sanjay Iyer', email: 'sanjay@team.test'),
  // Not in any team yet: shows the create / join welcome screen.
  Member(id: 'm8', fullName: 'Nisha Patel', email: 'nisha@team.test'),
];

/// Arun (m1) is in PrepWisely and Acme Tutors. Campus Connect is for trying
/// out "Join with code" (CAMP99).
List<Team> buildMockTeams(DateTime now) {
  final created = now.subtract(const Duration(days: 60));
  return [
    Team(
      id: 'tm1',
      name: 'PrepWisely',
      colorIndex: 0,
      joinCode: 'PREP42',
      createdBy: 'm1',
      createdAt: created,
    ),
    Team(
      id: 'tm2',
      name: 'Acme Tutors',
      colorIndex: 3,
      joinCode: 'ACME77',
      createdBy: 'm6',
      createdAt: created,
    ),
    Team(
      id: 'tm3',
      name: 'Campus Connect',
      colorIndex: 1,
      joinCode: 'CAMP99',
      createdBy: 'm2',
      createdAt: created,
    ),
  ];
}

List<TeamMembership> buildMockMemberships(DateTime now) {
  TeamMembership m(String team, String member, int daysAgo, [TeamRole? r]) =>
      TeamMembership(
        teamId: team,
        memberId: member,
        role: r ?? TeamRole.member,
        joinedAt: now.subtract(Duration(days: daysAgo)),
      );
  return [
    m('tm1', 'm1', 60, TeamRole.owner),
    m('tm1', 'm2', 59),
    m('tm1', 'm3', 58),
    m('tm1', 'm4', 57),
    m('tm1', 'm5', 56),
    m('tm2', 'm6', 60, TeamRole.owner),
    m('tm2', 'm1', 40),
    m('tm2', 'm7', 30),
    m('tm3', 'm2', 60, TeamRole.owner),
    m('tm3', 'm4', 50),
  ];
}

List<Task> buildMockTasks(DateTime now) {
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);
  DateTime ago(int hours) => now.subtract(Duration(hours: hours));

  Task t(
    String id,
    String title, {
    String team = 'tm1',
    String description = '',
    TaskScope scope = TaskScope.common,
    TaskStatus status = TaskStatus.todo,
    TaskPriority priority = TaskPriority.medium,
    required String by,
    String? to,
    int? due,
    int createdHoursAgo = 48,
  }) {
    final created = ago(createdHoursAgo);
    return Task(
      id: id,
      teamId: team,
      title: title,
      description: description,
      scope: scope,
      status: status,
      priority: priority,
      createdBy: by,
      assignedTo: scope == TaskScope.personal ? by : to,
      dueDate: due == null ? null : day(due),
      createdAt: created,
      updatedAt: created,
      completedAt: status == TaskStatus.done ? ago(createdHoursAgo ~/ 2) : null,
    );
  }

  return [
    // Common work
    t(
      't1',
      'Add 20 aptitude questions on percentages',
      description: 'Mix of easy and medium. Follow the quality guidelines doc.',
      priority: TaskPriority.high,
      by: 'm2',
      to: 'm3',
      due: 2,
      status: TaskStatus.inProgress,
    ),
    t(
      't2',
      'Review coding questions batch #4',
      description:
          'Check test cases and solutions for the 6 new array problems.',
      by: 'm2',
      to: 'm4',
      due: 1,
    ),
    t(
      't3',
      'Onboard Sri Ram Engineering College',
      description: 'Create departments, batches and the TPO account.',
      priority: TaskPriority.high,
      by: 'm1',
      to: 'm5',
      due: -1,
    ),
    t(
      't4',
      'Fix SerpApi jobs sync schedule',
      description: 'Sync is not running daily. Also protect the endpoint.',
      priority: TaskPriority.high,
      by: 'm1',
      to: 'm1',
      due: 0,
    ),
    t(
      't5',
      'Write onboarding guide for new colleges',
      by: 'm5',
      to: 'm2',
      due: 6,
      priority: TaskPriority.low,
    ),
    t('t6', 'Prepare TCS NQT mock test series', by: 'm1', to: 'm2', due: 10),
    t(
      't7',
      'Migrate prepcode jobs table to prepwisely',
      description: 'Move jobs into prepwisely with a pc_ prefix.',
      by: 'm1',
      due: 14,
    ),
    t(
      't8',
      'Proofread logical reasoning set',
      by: 'm2',
      to: 'm4',
      status: TaskStatus.done,
      createdHoursAgo: 96,
    ),
    t(
      't9',
      'Set up batches for KPR college',
      by: 'm1',
      to: 'm5',
      status: TaskStatus.done,
      createdHoursAgo: 120,
    ),
    t(
      't10',
      'Design certificate template',
      by: 'm2',
      to: 'm3',
      due: 4,
      priority: TaskPriority.low,
    ),

    // Personal to-dos
    t(
      'p1',
      'Weekly progress report',
      scope: TaskScope.personal,
      by: 'm1',
      due: 3,
    ),
    t(
      'p2',
      'Call college placement coordinator',
      scope: TaskScope.personal,
      by: 'm1',
      priority: TaskPriority.high,
      due: 0,
    ),
    t(
      'p3',
      'Read Supabase RLS docs',
      scope: TaskScope.personal,
      by: 'm1',
      priority: TaskPriority.low,
    ),
    t(
      'p4',
      'Update invoice sheet',
      scope: TaskScope.personal,
      by: 'm1',
      status: TaskStatus.done,
      createdHoursAgo: 30,
    ),
    t(
      'p5',
      'Draft question ideas for DSA',
      scope: TaskScope.personal,
      by: 'm3',
      due: 5,
    ),
    t('p6', 'Plan next week reviews', scope: TaskScope.personal, by: 'm4'),

    // Acme Tutors
    t(
      'a1',
      'Finalise weekend batch timetable',
      team: 'tm2',
      priority: TaskPriority.high,
      by: 'm6',
      to: 'm1',
      due: -1,
    ),
    t(
      'a2',
      'Record demo class video',
      team: 'tm2',
      by: 'm6',
      to: 'm7',
      due: 3,
      status: TaskStatus.inProgress,
    ),
    t(
      'a3',
      'Send fee reminders to parents',
      team: 'tm2',
      by: 'm1',
      to: 'm7',
      due: 1,
    ),
    t(
      'a4',
      'Hire a physics tutor',
      team: 'tm2',
      by: 'm6',
      to: 'm6',
      status: TaskStatus.done,
      createdHoursAgo: 200,
    ),
    t(
      'a5',
      'Update parents WhatsApp group',
      team: 'tm2',
      scope: TaskScope.personal,
      by: 'm1',
      due: 0,
    ),

    // Campus Connect
    t(
      'c1',
      'Collect resumes from final years',
      team: 'tm3',
      by: 'm2',
      to: 'm4',
      due: 2,
    ),
    t('c2', 'Plan mock interview day', team: 'tm3', by: 'm4', to: 'm2', due: 7),
  ];
}
