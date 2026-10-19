import 'package:flutter/material.dart';

import '../models/member.dart';
import '../theme/app_theme.dart';

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.member,
    this.radius = 16,
    this.ring = false,
  });

  /// `null` renders an "unassigned" placeholder.
  final Member? member;
  final double radius;

  /// Draws a brand-coloured selection ring around the avatar.
  final bool ring;

  static const _palette = [
    Color(0xFF7C5CFC),
    Color(0xFF0FB5AE),
    Color(0xFFF97316),
    Color(0xFFEC4899),
    Color(0xFF3B82F6),
    Color(0xFF16A34A),
    Color(0xFFCA8A04),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = member;
    final Widget avatar;
    if (m == null) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: c.surfaceMuted,
        child: Icon(
          Icons.person_outline_rounded,
          size: radius * 1.05,
          color: c.textMuted,
        ),
      );
    } else {
      final color = _palette[m.id.hashCode.abs() % _palette.length];
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: color.withValues(alpha: 0.16),
        child: Text(
          m.initials,
          style: TextStyle(
            fontSize: radius * 0.72,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
      );
    }
    if (!ring) return avatar;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.brand, width: 2),
      ),
      child: avatar,
    );
  }
}

class PersonOption {
  const PersonOption({
    required this.value,
    required this.label,
    this.member,
    this.icon,
  });

  final String? value;
  final String label;
  final Member? member;

  /// Shown instead of initials when [member] is null.
  final IconData? icon;
}

/// Horizontal row of avatars to pick a person (or "everyone"/"unassigned").
class PersonSelector extends StatelessWidget {
  const PersonSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<PersonOption> options;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final o = options[i];
          final isSelected = o.value == selected;
          return Semantics(
            selected: isSelected,
            button: true,
            label: o.label,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelected(o.value),
              child: SizedBox(
                width: 70,
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? c.brand : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: o.member != null
                          ? MemberAvatar(member: o.member, radius: 20)
                          : CircleAvatar(
                              radius: 20,
                              backgroundColor: isSelected
                                  ? c.brandSoft
                                  : c.surfaceMuted,
                              child: Icon(
                                o.icon ?? Icons.person_outline_rounded,
                                size: 20,
                                color: isSelected ? c.brand : c.textMuted,
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      o.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? c.text : c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
