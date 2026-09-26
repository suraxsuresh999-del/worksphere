import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/enums/enums.dart';

Future<void> showVerificationRequiredDialog(
  BuildContext context,
  VerificationStatus status,
) {
  final message = switch (status) {
    VerificationStatus.pending =>
      'Your verification is currently under review.',
    VerificationStatus.rejected =>
      'Your verification was rejected. Please review and resubmit your documents.',
    VerificationStatus.reuploadRequired =>
      'Please upload the required documents again.',
    _ => 'Please complete your verification before using this feature.',
  };
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Verification required'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            context.push(RouteNames.verification);
          },
          child: Text(
            status == VerificationStatus.pending
                ? 'View verification'
                : 'Complete verification',
          ),
        ),
      ],
    ),
  );
}
