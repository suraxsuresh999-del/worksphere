import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router/route_names.dart';

class ApplyJobScreen extends StatefulWidget {
  const ApplyJobScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<ApplyJobScreen> createState() => _ApplyJobScreenState();
}

class _ApplyJobScreenState extends State<ApplyJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _letter = TextEditingController();
  final _bid = TextEditingController();
  final _duration = TextEditingController();
  bool _agreed = false;
  bool _submitting = false;

  @override
  void dispose() {
    _letter.dispose();
    _bid.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || !_agreed || _submitting) {
      if (!_agreed) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confirm that you understand the requirements.')));
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _submitting = true);
    try {
      await Supabase.instance.client.from('job_applications').insert({
        'job_id': widget.jobId,
        'freelancer_id': user.id,
        'cover_letter': _letter.text.trim(),
        'bid_amount': double.parse(_bid.text.trim()),
        'estimated_duration': _duration.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your proposal has been submitted.')));
      context.go(RouteNames.applications);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      final duplicate = error.code == '23505';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(duplicate ? 'You have already applied to this job.' : 'Unable to submit your proposal. Please try again.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to submit your proposal. Please try again.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Submit proposal')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Tell the client why you are a great fit.', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _letter,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: 'Cover letter', hintText: 'Describe your approach, relevant experience, and deliverables.'),
                  validator: (value) => value == null || value.trim().length < 20 ? 'Write at least 20 characters.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bid,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Bid amount', prefixText: '₹ '),
                  validator: (value) => (double.tryParse(value?.trim() ?? '') ?? 0) <= 0 ? 'Enter a valid amount.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _duration,
                  decoration: const InputDecoration(labelText: 'Delivery time', hintText: 'For example, 7 days'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter an estimated delivery time.' : null,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _agreed,
                  onChanged: (value) => setState(() => _agreed = value ?? false),
                  title: const Text('I understand the project requirements.'),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_outlined),
                  label: const Text('Submit proposal'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
