import 'package:flutter/material.dart';

import '../data/task_store.dart';
import '../models/team.dart';
import '../screens/team_setup_screen.dart';
import '../theme/app_theme.dart';
import 'account_button.dart';
import 'task_badges.dart';

/// Team logo colours, picked when creating a team.
const teamPalette = [
  Color(0xFF6D5DFC),
  Color(0xFF0FB5AE),
  Color(0xFFF97316),
  Color(0xFFEC4899),
  Color(0xFF3B82F6),
  Color(0xFF16A34A),
  Color(0xFFCA8A04),
  Color(0xFF475569),
];

Color teamColor(int index) => teamPalette[index % teamPalette.length];

/// Rounded square with the team's initials, optionally with an alert dot.
class TeamLogo extends StatelessWidget {
  const TeamLogo({
    super.key,
    required this.initials,
    required this.colorIndex,
    this.size = 36,
    this.dot = false,
  });

  TeamLogo.of(Team team, {Key? key, double size = 36, bool dot = false})
    : this(
        key: key,
        initials: team.initials,
        colorIndex: team.colorIndex,
        size: size,
        dot: dot,
      );

  final String initials;
  final int colorIndex;
  final double size;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final color = teamColor(colorIndex);
    final logo = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.18)!],
        ),
      ),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.38,
          letterSpacing: 0.2,
        ),
      ),
    );
    if (!dot) return logo;
    final dotSize = (size * 0.32).clamp(9.0, 14.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        logo,
        Positioned(
          right: -3,
          top: -3,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: context.colors.danger,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.canvas, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Top bar on every home tab: which team you're in (tap to switch) and your
/// account.
class TeamBar extends StatelessWidget {
  const TeamBar({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = context.colors;
    final team = store.currentTeam!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                button: true,
                label: 'Switch team. Current team ${team.name}',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => showTeamSwitcher(context),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TeamLogo.of(team, dot: store.hasUrgentElsewhere),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 20,
                          color: c.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const AccountButton(),
        ],
      ),
    );
  }
}

Future<void> showTeamSwitcher(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _TeamSwitcherSheet(),
  );
}

class _TeamSwitcherSheet extends StatelessWidget {
  const _TeamSwitcherSheet();

  void _push(BuildContext context, Widget screen) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = context.colors;
    final current = store.currentTeam;
    final teams = store.teams;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text('Your teams', style: context.text.titleLarge),
              ),
              for (final team in teams) ...[
                _TeamRow(
                  team: team,
                  selected: team.id == current?.id,
                  memberCount: store.membersOf(team.id).length,
                  open: store.myOpenCountIn(team.id),
                  urgent: store.myUrgentCountIn(team.id),
                  onTap: () {
                    store.selectTeam(team.id);
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 4),
              Divider(color: c.border),
              const SizedBox(height: 8),
              if (current != null)
                _ActionRow(
                  icon: Icons.person_add_alt_rounded,
                  label: 'Invite people to ${current.name}',
                  onTap: () {
                    Navigator.of(context).pop();
                    showInviteSheet(context, current);
                  },
                ),
              _ActionRow(
                icon: Icons.add_rounded,
                label: 'Create a team',
                onTap: () => _push(context, const TeamFormScreen()),
              ),
              _ActionRow(
                icon: Icons.key_rounded,
                label: 'Join with a code',
                onTap: () => _push(context, const JoinTeamScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.team,
    required this.selected,
    required this.memberCount,
    required this.open,
    required this.urgent,
    required this.onTap,
  });

  final Team team;
  final bool selected;
  final int memberCount;
  final int open;
  final int urgent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.brandSoft : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? c.brand : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                TeamLogo.of(team, size: 44, dot: !selected && urgent > 0),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$memberCount ${memberCount == 1 ? 'member' : 'members'}'
                        ' · $open open for you',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (urgent > 0) ...[
                  const SizedBox(width: 8),
                  SoftChip(
                    icon: Icons.warning_amber_rounded,
                    label: '$urgent',
                    color: c.danger,
                    background: c.dangerSoft,
                  ),
                ],
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle_rounded, color: c.brand),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: c.border, width: 1.5),
              ),
              child: Icon(icon, color: c.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
