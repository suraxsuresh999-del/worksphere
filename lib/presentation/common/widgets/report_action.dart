import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportAction extends StatelessWidget {
  const ReportAction({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetName,
  });
  final String targetType;
  final String targetId;
  final String targetName;

  Future<void> _report(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.id == targetId) return;
    final description = TextEditingController();
    var category = 'other';
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Report $targetName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: category,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'scam', child: Text('Scam or fraud')),
                  DropdownMenuItem(
                    value: 'harassment',
                    child: Text('Harassment'),
                  ),
                  DropdownMenuItem(
                    value: 'inappropriate',
                    child: Text('Inappropriate content'),
                  ),
                  DropdownMenuItem(
                    value: 'payment_dispute',
                    child: Text('Payment dispute'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => category = value);
                },
              ),
              TextField(
                controller: description,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'What happened?'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'category': category,
                'description': description.text.trim(),
              }),
              child: const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
    description.dispose();
    if (values == null || values['description']!.isEmpty) return;
    try {
      await Supabase.instance.client.from('reports').insert({
        'reporter_id': user.id,
        'target_type': targetType,
        'target_id': targetId,
        'category': values['category'],
        'description': values['description'],
      });
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted for review.')),
        );
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to submit this report.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Report',
    icon: const Icon(Icons.flag_outlined),
    onPressed: () => _report(context),
  );
}
