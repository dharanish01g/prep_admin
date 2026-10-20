import 'package:flutter/material.dart';

import '../config.dart';
import '../data/task_remote.dart';
import '../data/task_store.dart';
import '../theme/app_theme.dart';
import 'member_avatar.dart';
import 'ui.dart';

enum _AccountAction { privacy, signOut, delete }

/// Avatar with the signed-in member's details, privacy policy, sign out and
/// account deletion.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  Future<void> _onSelected(BuildContext context, _AccountAction action) async {
    final store = StoreScope.read(context);
    switch (action) {
      case _AccountAction.privacy:
        await openLink(context, privacyPolicyUrl);
      case _AccountAction.signOut:
        await store.signOut();
      case _AccountAction.delete:
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => DeleteAccountDialog(store: store),
        );
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
          _AccountAction.privacy,
          Icons.privacy_tip_outlined,
          'Privacy policy',
          c.text,
        ),
        _item(
          _AccountAction.signOut,
          Icons.logout_rounded,
          'Sign out',
          c.danger,
        ),
        const PopupMenuDivider(),
        _item(
          _AccountAction.delete,
          Icons.delete_forever_outlined,
          'Delete account',
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

/// Explains what deletion removes and asks the user to type DELETE first.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.store});

  final TaskStore store;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  static const _word = 'DELETE';
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  bool get _ready => _confirm.text.trim().toUpperCase() == _word;

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await widget.store.deleteAccount();
    } on TaskRemoteException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
      return;
    }
    // Signed out now: the app has already swapped to the login screen.
    navigator.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your account, name and email, and '
              'your personal to-dos in every team. Tasks assigned to you '
              'become unassigned. Teams you own pass to the longest-standing '
              "member, and teams where you're the only member are deleted "
              'with all their tasks.\n\nThis cannot be undone.',
            ),
            const SizedBox(height: 16),
            Text(
              'Type $_word to confirm',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirm,
              enabled: !_busy,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: _word),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: c.danger, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.danger),
          onPressed: _busy || !_ready ? null : _delete,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text('Delete account'),
        ),
      ],
    );
  }
}
