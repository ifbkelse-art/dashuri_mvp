import 'package:dashuri_core/dashuri_core.dart';

/// Plain-language copy for sign-in failures (A03–A06). Never blames the user.
String signInFailureMessage(Failure failure, {required bool otpStep}) =>
    switch (failure) {
      ValidationFailure(:final fieldErrors)
          when fieldErrors['phone'] == 'invalid_phone' =>
        'Enter a valid 10-digit Indian mobile number.',
      ValidationFailure(:final fieldErrors) when fieldErrors['code'] != null =>
        'Enter the 6-digit code from the SMS.',
      ValidationFailure() || UnauthenticatedFailure() when otpStep =>
        "That code didn't match or has expired.",
      ValidationFailure() =>
        "We couldn't send a code to that number. Check it and try again.",
      RateLimitedFailure() =>
        'Too many attempts. Please wait a few minutes before trying again.',
      _ => failureMessage(failure),
    };
