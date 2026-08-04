import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../providers/auth_provider.dart';
import '../shell/home_shell.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, required this.siteId});

  final int siteId;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _company = TextEditingController();
  final _designation = TextEditingController();
  String? _gender;

  static const _genders = ['Female', 'Male', 'Prefer not to say'];

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _company, _designation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      await context.read<AuthProvider>().register(
            firstname: _first.text.trim(),
            lastname: _last.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            companyName: _company.text.trim().isEmpty ? null : _company.text.trim(),
            designation:
                _designation.text.trim().isEmpty ? null : _designation.text.trim(),
            gender: _gender,
            siteId: widget.siteId,
          );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (mounted) showPulseSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set up your profile', style: theme.textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  'This is what neighbours and the estate team see when you post or book.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                _Field(
                  label: 'First name',
                  controller: _first,
                  hint: 'Aarav',
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'First name is required' : null,
                ),
                _Field(
                  label: 'Last name',
                  controller: _last,
                  hint: 'Mehta',
                  textCapitalization: TextCapitalization.words,
                ),
                _Field(
                  label: 'Work email',
                  controller: _email,
                  hint: 'aarav@company.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return null;
                    final ok = RegExp(r'^[\w.\-+]+@[\w\-]+\.[\w.\-]+$').hasMatch(value);
                    return ok ? null : 'Enter a valid email address';
                  },
                ),
                _Field(
                  label: 'Company',
                  controller: _company,
                  hint: 'Nexus Labs',
                  textCapitalization: TextCapitalization.words,
                ),
                _Field(
                  label: 'Designation',
                  controller: _designation,
                  hint: 'Engineering Lead',
                  textCapitalization: TextCapitalization.words,
                ),
                Text('Gender', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: _genders
                      .map((g) => ChoiceChip(
                            label: Text(g),
                            selected: _gender == g,
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _gender == g
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                            onSelected: (_) => setState(
                              () => _gender = _gender == g ? null : g,
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 36),
                FilledButton(
                  onPressed: auth.busy ? null : _submit,
                  child: auth.busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              validator: validator,
              decoration: InputDecoration(hintText: hint),
            ),
          ],
        ),
      );
}
