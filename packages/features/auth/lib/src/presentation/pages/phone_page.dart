import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/sign_in_cubit.dart';
import '../../domain/entities/phone_number.dart';
import '../widgets/auth_copy.dart';
import '../widgets/auth_scaffold.dart';

/// A03 log in / A04 registration: phone number entry (+91 only, D-02:
/// phone OTP is the only sign-in method).
class PhonePage extends StatefulWidget {
  const PhonePage({super.key, this.register = false});

  /// A04 copy ("What's your number?") instead of A03 ("Welcome back").
  final bool register;

  @override
  State<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends State<PhonePage> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => IndianPhoneNumber.localDigits(_controller.text) != null;

  void _submit() {
    if (!_valid) return;
    context.read<SignInCubit>().sendCode(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<SignInCubit, SignInState>(
      listenWhen: (a, b) => a.codesSent != b.codesSent,
      listener: (context, state) =>
          context.push(RoutePaths.verifyOtp, extra: state.phone),
      builder: (context, state) {
        final failure = state.step == SignInStep.enterPhone
            ? state.failure
            : null;
        final busy = state.step == SignInStep.sendingCode;
        return AuthScaffold(
          step: widget.register ? 1 : null,
          title: widget.register ? "What's your number?" : 'Welcome back',
          subtitle: widget.register
              ? "We'll text you a code to verify it's you. Your number is "
                    'never shown to anyone.'
              : 'Log in with the phone number you used to create your '
                    'account.',
          bottom: PrimaryButton(
            label: 'Send code',
            busy: busy,
            onPressed: _valid ? _submit : null,
          ),
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                LengthLimitingTextInputFormatter(11),
              ],
              onSubmitted: (_) => _submit(),
              style: theme.textTheme.titleLarge,
              decoration: InputDecoration(
                labelText: 'Mobile number',
                hintText: '10-digit number',
                errorText: failure == null
                    ? null
                    : signInFailureMessage(failure, otpStep: false),
                errorMaxLines: 3,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Text(
                    '🇮🇳 +91',
                    style: theme.textTheme.titleMedium,
                    semanticsLabel: 'India, plus 91',
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0),
              ),
            ),
            const SizedBox(height: DashuriTokens.space3),
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: DashuriTokens.space2),
                Expanded(
                  child: Text(
                    widget.register
                        ? 'Protected and private. Used only for sign-in and '
                              'safety.'
                        : "We'll send a 6-digit code by SMS.",
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DashuriTokens.space5),
            Center(
              child: TextButton(
                onPressed: () => context.pushReplacement(
                  widget.register
                      ? RoutePaths.signIn
                      : '${RoutePaths.signIn}?mode=register',
                ),
                child: Text(
                  widget.register
                      ? 'Already have an account? Log in'
                      : 'New to Dashuri? Create account',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
