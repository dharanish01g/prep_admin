import 'package:flutter/material.dart';

import '../data/task_store.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';
import 'member_avatar.dart';

enum _AccountAction { settings, signOut }

/// Avatar with the signed-in member's details, settings and sign out.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  Future<void> _onSelected(BuildContext context, _AccountAction action) async {
    final store = StoreScope.read(context);
    switch (action) {
      case _AccountAction.settings:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      case _AccountAction.signOut:
        await store.signOut();
    }
  }

  PopupMenuItem<_AccountAction> _item(
    _AccountAction value,
    IconData icon,
    String label,
    Color color,
  ) => PopupMenuItem<_AccountAction>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = context.colors;
    final me = store.me;
    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account',
      offset: const Offset(0, 56),
      onSelected: (action) => _onSelected(context, action),
      itemBuilder: (context) => [
        PopupMenuItem<_AccountAction>(
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
        _item(
          _AccountAction.settings,
          Icons.settings_outlined,
          'Settings',
          c.text,
        ),
        _item(
          _AccountAction.signOut,
          Icons.logout_rounded,
          'Sign out',
          c.danger,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: MemberAvatar(member: me, radius: 20, ring: true),
      ),
    );
  }
}
