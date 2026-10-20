import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config.dart';
import '../data/task_remote.dart';
import '../data/task_store.dart';
import '../theme/app_theme.dart';
import '../utils/versions.dart';
import '../widgets/member_avatar.dart';
import '../widgets/ui.dart';

/// Name, theme, privacy policy, updates and account deletion.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = context.colors;
    // Signed out (account just deleted): this page is about to close.
    final me = store.currentUser;
    if (me == null) return Scaffold(appBar: AppBar());

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Row(
            children: [
              MemberAvatar(member: me, radius: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      me.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textSecondary, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const FieldLabel('Profile'),
          Card(
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Name',
                  value: me.fullName,
                  trailing: Icon(Icons.edit_outlined, color: c.textMuted),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => EditNameDialog(store: store),
                  ),
                ),
                const Divider(indent: 54),
                _SettingsRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  value: me.email,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const FieldLabel('Theme'),
          PillToggle<ThemeMode>(
            options: const [
              (ThemeMode.system, 'System', Icons.brightness_auto_outlined),
              (ThemeMode.light, 'Light', Icons.light_mode_outlined),
              (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
            ],
            selected: store.themeMode.value,
            onChanged: store.setThemeMode,
          ),
          const SizedBox(height: 24),
          const FieldLabel('About'),
          Card(
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy policy',
                  trailing: Icon(Icons.open_in_new_rounded, color: c.textMuted),
                  onTap: () => openLink(context, privacyPolicyUrl),
                ),
                const Divider(indent: 54),
                const _VersionRow(),
                const Divider(indent: 54),
                const _UpdateRow(),
              ],
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => DeleteAccountDialog(store: store),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.danger,
              side: BorderSide(color: c.danger.withValues(alpha: 0.4)),
            ),
            icon: const Icon(Icons.delete_forever_outlined, size: 20),
            label: const Text('Delete account'),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = this.value;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: c.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: value == null
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: value == null ? 15 : 12.5,
                      color: value == null ? c.text : c.textMuted,
                    ),
                  ),
                  if (value != null)
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: c.text,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) => _SettingsRow(
        icon: Icons.info_outline_rounded,
        label: 'Version',
        value: snapshot.data?.version ?? '',
      ),
    );
  }
}

/// Compares the installed version with the newest one in `app_versions`.
class _UpdateRow extends StatefulWidget {
  const _UpdateRow();

  @override
  State<_UpdateRow> createState() => _UpdateRowState();
}

class _UpdateRowState extends State<_UpdateRow> {
  bool _checking = false;

  Future<void> _check() async {
    final store = StoreScope.read(context);
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    setState(() => _checking = true);
    final String installed;
    final AppRelease? latest;
    try {
      installed = (await PackageInfo.fromPlatform()).version;
      latest = await store.latestRelease(platform);
    } on TaskRemoteException catch (e) {
      if (mounted) {
        setState(() => _checking = false);
        showErrorSnackBar(context, e);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _checking = false);
    await showDialog<void>(
      context: context,
      builder: (_) =>
          latest != null && isNewerVersion(latest.version, installed)
          ? _UpdateAvailableDialog(release: latest, installed: installed)
          : AlertDialog(
              title: const Text("You're up to date"),
              content: Text('Tiny Tasks $installed is the latest version.'),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _SettingsRow(
      icon: Icons.system_update_outlined,
      label: 'Check for updates',
      trailing: _checking
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: c.brand,
              ),
            )
          : Icon(Icons.chevron_right_rounded, color: c.textMuted),
      onTap: _checking ? null : _check,
    );
  }
}

class _UpdateAvailableDialog extends StatelessWidget {
  const _UpdateAvailableDialog({
    required this.release,
    required this.installed,
  });

  final AppRelease release;
  final String installed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final url = release.downloadUrl;
    return AlertDialog(
      title: const Text('Update available'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version ${release.version} is out. You have $installed.'),
            if (release.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              const FieldLabel("What's new"),
              Text(
                release.notes.trim(),
                style: TextStyle(color: c.textSecondary),
              ),
            ],
            if (url == null) ...[
              const SizedBox(height: 16),
              Text(
                'Ask your team owner for the new version.',
                style: TextStyle(color: c.textSecondary),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(url == null ? 'OK' : 'Later'),
        ),
        if (url != null)
          FilledButton(
            onPressed: () {
              openLink(context, url);
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
      ],
    );
  }
}

/// Edits my name; teammates see the new one everywhere.
class EditNameDialog extends StatefulWidget {
  const EditNameDialog({super.key, required this.store});

  final TaskStore store;

  @override
  State<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<EditNameDialog> {
  late final _name = TextEditingController(text: widget.store.me.fullName);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await widget.store.updateName(_name.text);
    } on TaskRemoteException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: const Text('Your name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            enabled: !_busy,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Full name',
              counterText: '',
            ),
            onSubmitted: (_) => _busy ? null : _save(),
          ),
          const SizedBox(height: 8),
          Text(
            'Your teammates see this name.',
            style: TextStyle(fontSize: 12.5, color: c.textMuted),
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
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const ButtonSpinner() : const Text('Save'),
        ),
      ],
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
