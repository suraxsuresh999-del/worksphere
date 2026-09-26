import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../app/di/auth_providers.dart';
import '../../../app/router/route_names.dart';
import '../../common/widgets/ws_button.dart';
import '../../common/widgets/ws_text_field.dart';
import '../../../core/utils/validators.dart';

class FreelancerProfileSetupScreen extends ConsumerStatefulWidget {
  const FreelancerProfileSetupScreen({super.key});

  @override
  ConsumerState<FreelancerProfileSetupScreen> createState() =>
      _FreelancerProfileSetupScreenState();
}

class _FreelancerProfileSetupScreenState
    extends ConsumerState<FreelancerProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bioController = TextEditingController();
  final _skillsController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isStudent = false;
  bool _isLoading = false;
  PlatformFile? _resume;

  Future<void> _pickResume() async {
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
    );
    if (selection.isEmpty) return;
    final file = selection.first;
    final size = await file.length();
    if (size == 0 || size > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose a PDF, DOC, or DOCX file smaller than 5 MB.'),
          ),
        );
      }
      return;
    }
    setState(() => _resume = file);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bioController.dispose();
    _skillsController.dispose();
    _hourlyRateController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.completeFreelancerProfile(
        title: _titleController.text.trim(),
        bio: _bioController.text.trim(),
        hourlyRate: _hourlyRateController.text.trim(),
        location: _locationController.text.trim(),
        skills: _skillsController.text.trim(),
        isStudent: _isStudent,
      );
      if (_resume != null) {
        await repository.uploadResume(_resume!);
      }
      if (!mounted) return;
      if (_isStudent) {
        await context.push(RouteNames.verification);
        if (!mounted) return;
      }
      context.go(RouteNames.home);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Freelancer Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Build your freelancer profile',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Add your professional details so clients can hire you with confidence.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              WsTextField(
                label: 'Professional Title',
                hint: 'e.g. Senior Flutter Developer',
                controller: _titleController,
                validator: Validators.required,
              ),
              const SizedBox(height: 20),
              WsTextField(
                label: 'Bio / About',
                hint: 'Tell clients about your skills and experience',
                controller: _bioController,
                maxLines: 4,
                validator: Validators.required,
              ),
              const SizedBox(height: 20),
              WsTextField(
                label: 'Skills',
                hint: 'e.g. Flutter, Dart, Supabase',
                controller: _skillsController,
                validator: Validators.required,
              ),
              const SizedBox(height: 20),
              WsTextField(
                label: 'Hourly Rate (₹)',
                hint: 'e.g. 500',
                controller: _hourlyRateController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.currency_rupee,
                validator: Validators.required,
              ),
              const SizedBox(height: 20),
              WsTextField(
                label: 'Location',
                hint: 'e.g. Chennai',
                controller: _locationController,
                validator: Validators.required,
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _resume == null
                      ? Icons.attach_file_outlined
                      : Icons.check_circle_outline,
                  color: _resume == null ? null : Colors.green,
                ),
                title: const Text('Attach resume (optional)'),
                subtitle: Text(
                  _resume?.name ?? 'PDF, DOC, or DOCX · maximum 5 MB',
                ),
                trailing: TextButton(
                  onPressed: _pickResume,
                  child: Text(_resume == null ? 'Upload' : 'Replace'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Are you a student?',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Switch(
                    value: _isStudent,
                    onChanged: (value) {
                      setState(() => _isStudent = value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
              WsButton(
                text: 'Complete Profile',
                onPressed: _handleSave,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
