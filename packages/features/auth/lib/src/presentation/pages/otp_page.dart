import 'dart:async';

import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/sign_in_cubit.dart';
import '../../domain/entities/phone_number.dart';
import '../widgets/auth_copy.dart';
import '../widgets/auth_scaffold.dart';

/// A05 code entry and A06 error state. Auto-submits on the 6th digit;
/// resend is available after a countdown.
class OtpPage extends StatefulWidget {
  const OtpPage({super.key, this.resendAfter = const Duration(seconds: 30)});

  final Duration resendAfter;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = widget.resendAfter.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  void _onChanged(String value) {
    setState(() {});
    if (value.length == 6) context.read<SignInCubit>().verifyCode(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<SignInCubit, SignInState>(
      listenWhen: (a, b) =>
          a.codesSent != b.codesSent ||
          (a.failure != b.failure && b.failure != null),
      listener: (context, state) {
        if (state.failure == null) {
          _controller.clear();
          _startCountdown();
        }
      },
      builder: (context, state) {
        final failure = state.failure;
        final verifying =
            state.step == SignInStep.verifying ||
            state.step == SignInStep.signedIn;
        final sending = state.step == SignInStep.sendingCode;
        final error = failure == null
            ? null
            : signInFailureMessage(failure, otpStep: true);
        return AuthScaffold(
          step: 2,
          title: 'Enter the code',
          onBack: () =>
              context.canPop() ? context.pop() : context.go(RoutePaths.signIn),
          bottom: PrimaryButton(
            label: failure == null ? 'Verify' : 'Try again',
            busy: verifying,
            onPressed: _controller.text.length == 6
                ? () => context.read<SignInCubit>().verifyCode(_controller.text)
                : null,
          ),
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Sent to ${IndianPhoneNumber.format(state.phone)}. ',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(RoutePaths.signIn),
                  child: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: DashuriTokens.space4),
            _CodeBoxes(
              controller: _controller,
              focusNode: _focus,
              hasError: error != null,
              onChanged: _onChanged,
            ),
            if (error != null) ...[
              const SizedBox(height: DashuriTokens.space3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: DashuriTokens.space2),
                  Expanded(
                    child: Text(
                      error,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: DashuriTokens.space5),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text("Didn't get it? ", style: theme.textTheme.bodyMedium),
                if (_secondsLeft > 0)
                  Text(
                    'Resend code in ${DashuriFormat.duration(_secondsLeft)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  TextButton(
                    onPressed: sending
                        ? null
                        : () => context.read<SignInCubit>().resendCode(),
                    child: const Text('Resend code'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = controller.text;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Stack(
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < 6; i++) ...[
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 0.85,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: hasError
                              ? scheme.errorContainer
                              : scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(
                            DashuriTokens.radiusMedium,
                          ),
                          border: Border.all(
                            color: hasError
                                ? scheme.error
                                : i == text.length
                                ? scheme.primary
                                : scheme.outlineVariant,
                            width: i == text.length || hasError ? 1.5 : 1,
                          ),
                        ),
                        child: FittedBox(
                          child: Text(
                            i < text.length ? text[i] : '',
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (i < 5) const SizedBox(width: DashuriTokens.space2),
                ],
              ],
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  counterText: '',
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
