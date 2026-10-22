import 'package:flutter/material.dart';

import '../config.dart';
import '../data/task_store.dart';
import '../theme/app_theme.dart';
import '../widgets/member_avatar.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _creating = false;
  bool _busy = false;
  String? _error;

  /// Shown after signing up when the account needs confirming by email.
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final store = StoreScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final email = _email.text.trim();
    final error = _creating
        ? await store.signUp(
            fullName: _name.text,
            email: _email.text,
            password: _password.text,
            onCheckEmail: () {
              if (!mounted) return;
              // Their email stays filled in, ready to sign in once confirmed.
              _password.clear();
              setState(() {
                _creating = false;
                _notice =
                    'We sent a link to $email. Open it to confirm your '
                    'account, then sign in.';
              });
            },
          )
        : await store.signInWithEmail(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  void _toggleMode() => setState(() {
    _creating = !_creating;
    _error = null;
    _notice = null;
    _formKey.currentState?.reset();
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = StoreScope.of(context);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, top + 48, 24, 96),
              decoration: BoxDecoration(
                gradient: c.brandGradient,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(36),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.check_box_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Tiny Tasks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Plan, assign and track work together',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Card overlapping the hero
            Transform.translate(
              offset: const Offset(0, -64),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: c.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _creating
                                      ? 'Create your account'
                                      : 'Welcome back',
                                  style: context.text.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _creating
                                      ? 'Then create a team or join one with a code'
                                      : 'Sign in to see your teams',
                                  style: TextStyle(color: c.textSecondary),
                                ),
                                const SizedBox(height: 20),
                                if (_creating) ...[
                                  TextFormField(
                                    controller: _name,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    autofillHints: const [AutofillHints.name],
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      hintText: 'Your full name',
                                      prefixIcon: Icon(
                                        Icons.person_outline_rounded,
                                      ),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Enter your name'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    hintText: 'Email address',
                                    prefixIcon: Icon(
                                      Icons.mail_outline_rounded,
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || !v.trim().contains('@'))
                                      ? 'Enter a valid email'
                                      : null,
                                  onChanged: (_) =>
                                      setState(() => _error = null),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  autofillHints: [
                                    _creating
                                        ? AutofillHints.newPassword
                                        : AutofillHints.password,
                                  ],
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    hintText: _creating
                                        ? 'Password (8+ characters)'
                                        : 'Password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: _obscure
                                          ? 'Show password'
                                          : 'Hide password',
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Enter your password';
                                    }
                                    if (_creating && v.length < 8) {
                                      return 'Use at least 8 characters';
                                    }
                                    return null;
                                  },
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  _Message(
                                    text: _error!,
                                    icon: Icons.error_outline_rounded,
                                    color: c.danger,
                                    background: c.dangerSoft,
                                  ),
                                ],
                                if (_notice != null) ...[
                                  const SizedBox(height: 12),
                                  _Message(
                                    text: _notice!,
                                    icon: Icons.mark_email_read_outlined,
                                    color: c.info,
                                    background: c.infoSoft,
                                  ),
                                ],
                                const SizedBox(height: 20),
                                FilledButton(
                                  onPressed: _busy ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                  ),
                                  child: _busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _creating
                                              ? 'Create account'
                                              : 'Sign in',
                                        ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _busy ? null : _toggleMode,
                                  child: Text(
                                    _creating
                                        ? 'Already have an account? Sign in'
                                        : 'New here? Create an account',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => openLink(context, privacyPolicyUrl),
                          style: TextButton.styleFrom(
                            foregroundColor: c.textMuted,
                          ),
                          child: const Text('Privacy policy'),
                        ),
                        if (store.isMock) ...[
                          const SizedBox(height: 28),
                          Text(
                            'DEMO ACCOUNTS',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: c.textMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final m in store.allMembers)
                                Material(
                                  color: c.surface,
                                  shape: StadiumBorder(
                                    side: BorderSide(color: c.border),
                                  ),
                                  child: InkWell(
                                    customBorder: const StadiumBorder(),
                                    onTap: () {
                                      _email.text = m.email;
                                      _password.text = 'demo';
                                      setState(() => _error = null);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        4,
                                        12,
                                        4,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          MemberAvatar(member: m, radius: 13),
                                          const SizedBox(width: 8),
                                          Text(
                                            m.firstName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
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

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String text;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
