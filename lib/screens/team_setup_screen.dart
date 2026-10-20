import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/task_remote.dart';
import '../data/task_store.dart';
import '../models/team.dart';
import '../theme/app_theme.dart';
import '../widgets/account_button.dart';
import '../widgets/team_switcher.dart';
import '../widgets/ui.dart';

/// Shown after sign in when you're not in any team yet.
class NoTeamScreen extends StatelessWidget {
  const NoTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = context.colors;
    void open(Widget screen) => Navigator.of(context).push(
      MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => screen),
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 6, 8, 0),
                child: AccountButton(),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            gradient: c.brandGradient,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: const Icon(
                            Icons.workspaces_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Welcome, ${store.me.firstName}!',
                          textAlign: TextAlign.center,
                          style: context.text.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Each team is its own workspace, so work for '
                          'different companies never mixes. Create one or '
                          'join with an invite code.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.textSecondary,
                            height: 1.45,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _OptionCard(
                          icon: Icons.add_business_rounded,
                          title: 'Create a team',
                          message: 'Start a workspace and invite people.',
                          onTap: () => open(const TeamFormScreen()),
                        ),
                        const SizedBox(height: 12),
                        _OptionCard(
                          icon: Icons.key_rounded,
                          title: 'Join with a code',
                          message: 'Got an invite code from a teammate?',
                          onTap: () => open(const JoinTeamScreen()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconBadge(
                icon: icon,
                color: c.brand,
                background: c.brandSoft,
                size: 48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Create a team, or rename / recolour one when [teamId] is given.
class TeamFormScreen extends StatefulWidget {
  const TeamFormScreen({super.key, this.teamId});

  final String? teamId;

  @override
  State<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends State<TeamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  int _color = 0;
  bool _initialised = false;
  bool _busy = false;

  bool get _isEdit => widget.teamId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final store = StoreScope.read(context);
    final team = store.teamById(widget.teamId);
    if (team != null) {
      _name.text = team.name;
      _color = team.colorIndex;
    } else {
      // Pick a colour none of my teams use yet, if there is one.
      final used = {for (final t in store.teams) t.colorIndex};
      _color = List.generate(
        teamPalette.length,
        (i) => i,
      ).firstWhere((i) => !used.contains(i), orElse: () => 0);
    }
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final store = StoreScope.read(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      if (_isEdit) {
        await store.updateTeam(
          widget.teamId!,
          name: _name.text,
          colorIndex: _color,
        );
        navigator.pop();
        return;
      }
      final team = await store.createTeam(name: _name.text, colorIndex: _color);
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => TeamCreatedScreen(teamId: team.id),
        ),
      );
    } on TaskRemoteException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final preview = Team(
      id: '',
      name: _name.text.trim().isEmpty ? '?' : _name.text,
      colorIndex: _color,
      joinCode: '',
      createdBy: '',
      createdAt: DateTime(2000),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEdit ? 'Edit team' : 'Create a team'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Center(child: TeamLogo.of(preview, size: 84)),
            const SizedBox(height: 28),
            const FieldLabel('Team name'),
            TextFormField(
              controller: _name,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'e.g. PrepWisely, Acme Tutors',
                counterText: '',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Give your team a name'
                  : null,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            const FieldLabel('Colour'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < teamPalette.length; i++)
                  Semantics(
                    button: true,
                    selected: i == _color,
                    label: 'Colour ${i + 1}',
                    child: GestureDetector(
                      onTap: () => setState(() => _color = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == _color
                                ? teamPalette[i]
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: teamPalette[i],
                          child: i == _color
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: c.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "You'll be the owner. Next you'll get an invite code "
                        'to share with your team.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const ButtonSpinner()
                  : Text(_isEdit ? 'Save changes' : 'Create team'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Success step after creating a team: share the invite code.
class TeamCreatedScreen extends StatelessWidget {
  const TeamCreatedScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = context.colors;
    final team = store.teamById(teamId);
    if (team == null) return const Scaffold();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  TeamLogo.of(team, size: 84),
                  const SizedBox(height: 20),
                  Text(
                    '${team.name} is ready',
                    textAlign: TextAlign.center,
                    style: context.text.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share this code with your team. They tap "Join with a '
                    'code" and they\'re in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: 24),
                  InviteCodeCard(team: team),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the system share sheet with a ready-to-send invite.
Future<void> shareInvite(BuildContext context, Team team) {
  final box = context.findRenderObject() as RenderBox?;
  return SharePlus.instance.share(
    ShareParams(
      subject: 'Join ${team.name} on Tiny Tasks',
      text:
          'Join ${team.name} on Tiny Tasks.\n\n'
          'Open the app, tap "Join with a code" and enter: ${team.joinCode}',
      // Anchor for the iPad share popover.
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}

/// Bottom sheet with the current team's invite code; reachable from the team
/// switcher and the Team tab.
Future<void> showInviteSheet(BuildContext context, Team team) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final store = StoreScope.of(context);
      final current = store.teamById(team.id) ?? team;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Text(
                  'Invite people to ${current.name}',
                  style: context.text.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                child: Text(
                  'Anyone with this code can join straight away. Every member '
                  'can see it on the Team tab.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              InviteCodeCard(
                team: current,
                canRegenerate: store.isOwner(current.id),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The team's invite code with share and copy (and, for owners, regenerate).
class InviteCodeCard extends StatelessWidget {
  const InviteCodeCard({
    super.key,
    required this.team,
    this.canRegenerate = false,
  });

  final Team team;
  final bool canRegenerate;

  Future<void> _regenerate(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make a new code?'),
        content: const Text(
          'The current code will stop working. People already in the team '
          'stay in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('New code'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await StoreScope.read(context).regenerateJoinCode(team.id);
    } on TaskRemoteException catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INVITE CODE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: c.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      team.joinCode,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: c.brand,
                      ),
                    ),
                  ],
                ),
              ),
              if (canRegenerate)
                IconButton(
                  tooltip: 'Make a new code',
                  icon: Icon(Icons.refresh_rounded, color: c.textSecondary),
                  onPressed: () => _regenerate(context),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) => FilledButton.icon(
                    onPressed: () => shareInvite(context, team),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Share'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: team.joinCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class JoinTeamScreen extends StatefulWidget {
  const JoinTeamScreen({super.key});

  @override
  State<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends State<JoinTeamScreen> {
  final _code = TextEditingController();
  TeamPreview? _preview;
  String? _lookedUp;
  String? _lookupError;
  bool _looking = false;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _code.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    final code = _code.text;
    if (code.length < 6) {
      if (_lookedUp != null || _preview != null) {
        setState(() {
          _lookedUp = null;
          _preview = null;
          _lookupError = null;
        });
      }
      return;
    }
    if (code != _lookedUp) _lookup(code);
  }

  Future<void> _lookup(String code) async {
    setState(() {
      _lookedUp = code;
      _preview = null;
      _lookupError = null;
      _looking = true;
    });
    try {
      final preview = await StoreScope.read(context).previewTeam(code);
      if (!mounted || _code.text != code) return;
      setState(() {
        _preview = preview;
        _looking = false;
      });
    } on TaskRemoteException catch (e) {
      if (!mounted || _code.text != code) return;
      setState(() {
        _lookupError = e.message;
        _looking = false;
      });
    }
  }

  Future<void> _join(TeamPreview preview) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _joining = true);
    try {
      await store.joinTeam(_code.text);
      navigator.popUntil((r) => r.isFirst);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            preview.isMember
                ? "You're already in ${preview.name}"
                : 'Joined ${preview.name}',
          ),
        ),
      );
    } on TaskRemoteException catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final complete = _code.text.length == 6;
    final preview = _preview;
    final notFound = complete && !_looking && preview == null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Join a team'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Text(
            'Enter the 6-character invite code a teammate shared with you.',
            style: TextStyle(color: c.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _code,
            autofocus: true,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              TextInputFormatter.withFunction(
                (old, value) => value.copyWith(text: value.text.toUpperCase()),
              ),
            ],
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 10,
              color: c.text,
            ),
            decoration: InputDecoration(
              hintText: 'ABC123',
              hintStyle: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 10,
                color: c.textMuted.withValues(alpha: 0.5),
              ),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
              errorText: notFound
                  ? (_lookupError ??
                        'No team uses this code. Check it and try again.')
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _looking
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : preview == null
                ? const SizedBox.shrink()
                : _JoinPreview(
                    key: ValueKey(preview.id),
                    preview: preview,
                    busy: _joining,
                    onJoin: () => _join(preview),
                  ),
          ),
        ],
      ),
    );
  }
}

class _JoinPreview extends StatelessWidget {
  const _JoinPreview({
    super.key,
    required this.preview,
    required this.busy,
    required this.onJoin,
  });

  final TeamPreview preview;
  final bool busy;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = preview.memberCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                TeamLogo(
                  initials: preview.initials,
                  colorIndex: preview.colorIndex,
                  size: 52,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(preview.name, style: context.text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '$count ${count == 1 ? 'member' : 'members'}',
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : onJoin,
              child: busy
                  ? const ButtonSpinner()
                  : Text(
                      preview.isMember
                          ? 'Open ${preview.name}'
                          : 'Join ${preview.name}',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
