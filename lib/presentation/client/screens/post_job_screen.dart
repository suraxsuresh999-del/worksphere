import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/enums.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../common/widgets/verification_required_dialog.dart';
import '../../common/widgets/ws_button.dart';
import '../../common/widgets/ws_text_field.dart';

class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _skillsController = TextEditingController();
  final _categoryController = TextEditingController();
  String _experienceLevel = 'Intermediate';
  PlatformFile? _attachment;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _skillsController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _handlePostJob() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) return;
    final minimumBudget = double.tryParse(_budgetMinController.text.trim());
    final maximumBudget = double.tryParse(_budgetMaxController.text.trim());
    if ((_budgetMinController.text.trim().isNotEmpty &&
            minimumBudget == null) ||
        (_budgetMaxController.text.trim().isNotEmpty &&
            maximumBudget == null) ||
        (minimumBudget != null && minimumBudget < 0) ||
        (maximumBudget != null && maximumBudget < 0) ||
        (minimumBudget != null &&
            maximumBudget != null &&
            maximumBudget < minimumBudget)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid budget range.')),
      );
      return;
    }
    final account = ref.read(currentUserProvider).valueOrNull;
    final status = account?.verificationStatus ?? VerificationStatus.unverified;
    if (account?.type != UserType.client || !status.isVerified) {
      await showVerificationRequiredDialog(context, status);
      return;
    }

    setState(() => _isLoading = true);
    String? uploadedAttachmentPath;
    var published = false;
    try {
      if (_attachment != null) {
        final bytes = await _attachment!.readAsBytes();
        if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
          throw const _AttachmentException(
            'Choose an attachment smaller than 10 MB.',
          );
        }
        final safeName = _attachment!.name
            .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final fileName = safeName.isEmpty ? 'attachment' : safeName;
        uploadedAttachmentPath =
            'jobs/${account!.id}/${DateTime.now().millisecondsSinceEpoch}-$fileName';
        await Supabase.instance.client.storage
            .from('job-attachments')
            .uploadBinary(uploadedAttachmentPath, bytes);
      }
      await Supabase.instance.client.rpc(
        'publish_my_job',
        params: {
          'title_input': _titleController.text.trim(),
          'description_input': _descriptionController.text.trim(),
          'budget_min_input': minimumBudget,
          'budget_max_input': maximumBudget,
          'experience_level_input': _experienceLevel,
          'category_label_input': _categoryController.text.trim(),
          'required_skill_names_input': _skillsController.text
              .split(',')
              .map((skill) => skill.trim())
              .where((skill) => skill.isNotEmpty)
              .toList(),
          'attachment_paths_input': uploadedAttachmentPath == null
              ? <String>[]
              : <String>[uploadedAttachmentPath],
        },
      );
      published = true;
      if (!mounted) return;
      await _showSuccess();
    } on _AttachmentException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (!published && uploadedAttachmentPath != null) {
        try {
          await Supabase.instance.client.storage
              .from('job-attachments')
              .remove([uploadedAttachmentPath]);
        } catch (_) {
          // Cleanup is best effort; the storage policy prevents public access.
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to publish your job. Please check your verification and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccess() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Job Published Successfully!',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your job has been published and is now visible to eligible freelancers.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            context.go('/home');
          },
          child: const Text('Back to Dashboard'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            context.go('/my-jobs');
          },
          child: const Text('View My Jobs'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a Job')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Hire Tamil Nadu\'s Top Freelancers',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Describe your project to get proposals from qualified professionals.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              WsTextField(
                label: 'Job Title',
                hint: 'e.g. Build a Flutter E-commerce Mobile App',
                controller: _titleController,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              WsTextField(
                label: 'Job Description / Project Requirements',
                hint:
                    'Describe the scope, deliverables, and requirements in detail...',
                controller: _descriptionController,
                maxLines: 5,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              WsTextField(
                label: 'Required Skills',
                hint: 'e.g. Flutter, Dart, Supabase',
                controller: _skillsController,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _experienceLevel,
                decoration: const InputDecoration(
                  labelText: 'Experience Level',
                ),
                items: const ['Entry Level', 'Intermediate', 'Expert']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _experienceLevel = value!),
              ),
              const SizedBox(height: 20),
              WsTextField(
                label: 'Project Category',
                hint: 'e.g. Mobile Development',
                controller: _categoryController,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: WsTextField(
                      label: 'Min Budget (₹)',
                      hint: '5000',
                      controller: _budgetMinController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: WsTextField(
                      label: 'Max Budget (₹)',
                      hint: '20000',
                      controller: _budgetMaxController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.attach_file_outlined),
                title: Text(_attachment?.name ?? 'Attachments (optional)'),
                trailing: TextButton(
                  onPressed: () async {
                    final file = await FilePicker.pickFile();
                    if (file != null && mounted) {
                      setState(() => _attachment = file);
                    }
                  },
                  child: Text(_attachment == null ? 'Attach' : 'Change'),
                ),
              ),
              const SizedBox(height: 32),
              WsButton(
                text: 'Publish Job',
                onPressed: _handlePostJob,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentException implements Exception {
  const _AttachmentException(this.message);

  final String message;
}
