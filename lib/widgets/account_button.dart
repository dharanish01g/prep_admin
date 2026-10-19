import 'package:flutter/material.dart';

import '../data/task_store.dart';
import '../theme/app_theme.dart';
import 'member_avatar.dart';

/// Avatar with the signed-in member's details and sign out.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = context.colors;
    final me = store.me;
    return PopupMenuButton<void>(
      tooltip: 'Account',
      offset: const Offset(0, 56),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                MemberAvatar(member: me, radius: 20),
                const SizedBox(width: 12),
                // The menu caps its width, so long names and emails get "…".
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                      Text(
                        me.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: store.signOut,
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 20, color: c.danger),
              const SizedBox(width: 12),
              Text(
                'Sign out',
                style: TextStyle(fontWeight: FontWeight.w600, color: c.danger),
              ),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: MemberAvatar(member: me, radius: 20, ring: true),
      ),
    );
  }
}
