import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router/route_names.dart';
import '../../../core/enums/enums.dart';
import '../../../core/utils/validators.dart';
import '../../common/widgets/ws_button.dart';
import '../../common/widgets/ws_text_field.dart';

/// Collects all required information before an account is created. Private files
/// are sent only to the complete-registration Edge Function, never to a public URL.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{
    for (final key in [
      'fullName', 'email', 'phone', 'password', 'confirmPassword', 'country', 'state', 'city',
      'companyName', 'organizationType', 'jobTitle', 'industry', 'website', 'companyDescription',
      'requiredSkills', 'projectRequirements', 'budgetRange', 'headline', 'bio', 'primarySkill',
      'secondarySkills', 'yearsExperience', 'education', 'certifications', 'languages', 'hourlyRate',
      'portfolioUrl', 'otherProfiles', 'college', 'course', 'department', 'semester', 'studentId',
      'graduationYear', 'company', 'employmentTitle', 'employmentStart', 'workExperience', 'previousCompany',
      'previousTitle', 'otherStatusDetails'
    ]) key: TextEditingController(),
  };
  final Map<String, dynamic> _documents = {};
  UserType _role = UserType.freelancer;
  String _status = 'Student';
  String _gender = 'Prefer not to say';
  String _availability = 'Available';
  String _experienceLevel = 'Intermediate';
  DateTime? _dateOfBirth;
  bool _isLoading = false;
  bool _obscurePassword = true;

  TextEditingController _c(String name) => _controllers[name]!;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDocument(String type) async {
    // Some versions of file_picker expose a top-level FilePicker.pickFiles that
    // returns either a FilePickerResult-like object or a List<PlatformFile>.
    // Use dynamic handling to stay compatible across versions.
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    ); // user cancelled

    List files;
    files = result;

    if (files.isEmpty) return;

    final file = files.first;
    final size = (file.size as int);
    if (size == 0 || size > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a JPEG, PNG, or PDF smaller than 5 MB.')),
        );
      }
      return;
    }
    setState(() => _documents[type] = file);
  }

  String _mimeType(dynamic file) {
    final name = (file.name as String).toLowerCase();
    if (name.endsWith('.pdf')) return 'application/pdf';
    if (name.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }

  Future<List<int>> _documentBytes(dynamic file) async {
    // Prefer in-memory bytes when available (e.g., when withData: true was used).
    final bytes = file.bytes;
    if (bytes != null) return (bytes as List<int>).toList();

    // Fall back to reading from the file path on disk (mobile/desktop).
    if (file.path != null) {
      final f = File(file.path as String);
      return await f.readAsBytes();
    }

    throw Exception('Unable to read file bytes for ${file.name}');
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dateOfBirth == null) {
      _show('Select your date of birth.');
      return;
    }
    if (!_documents.containsKey('profile_photo')) {
      _show('A profile photo is required.');
      return;
    }
    if (_role == UserType.freelancer && _status == 'Student' && !_documents.containsKey('student_id')) {
      _show('Upload your college student ID card.');
      return;
    }
    if (_role == UserType.client && !_documents.containsKey('company_proof')) {
      _show('Upload a company verification document.');
      return;
    }
    if (_c('password').text != _c('confirmPassword').text) {
      _show('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final profile = <String, dynamic>{
        'full_name': _c('fullName').text.trim(), 'phone': _c('phone').text.trim(),
        'date_of_birth': _dateOfBirth!.toIso8601String().substring(0, 10),
        'country': _c('country').text.trim(), 'state': _c('state').text.trim(), 'city': _c('city').text.trim(),
        'gender': _gender, 'user_type': _role.value,
        if (_role == UserType.client) ...{
          'company_name': _c('companyName').text.trim(), 'organization_type': _c('organizationType').text.trim(),
          'job_title': _c('jobTitle').text.trim(), 'industry': _c('industry').text.trim(),
          'website': _c('website').text.trim(), 'company_description': _c('companyDescription').text.trim(),
          'required_skills': _csv('requiredSkills'), 'project_requirements': _c('projectRequirements').text.trim(),
          'experience_level': _experienceLevel, 'budget_range': _c('budgetRange').text.trim(),
        } else ...{
          'headline': _c('headline').text.trim(), 'bio': _c('bio').text.trim(), 'primary_skill': _c('primarySkill').text.trim(),
          'secondary_skills': _csv('secondarySkills'), 'years_experience': _c('yearsExperience').text.trim(),
          'education': _c('education').text.trim(), 'certifications': _c('certifications').text.trim(),
          'languages': _csv('languages'), 'hourly_rate': _c('hourlyRate').text.trim(), 'availability': _availability,
          'portfolio_url': _c('portfolioUrl').text.trim(), 'website': _c('website').text.trim(),
          'other_profiles': _c('otherProfiles').text.trim(), 'current_status': _status,
          'status_details': _statusDetails(),
        },
      };
      final documents = await Future.wait(
        _documents.entries.map((entry) async {
          final bytes = await _documentBytes(entry.value);
          return {
            'type': entry.key,
            'name': entry.value.name,
            'mimeType': _mimeType(entry.value),
            'base64': base64Encode(bytes),
          };
        }),
      );
      final response = await Supabase.instance.client.functions.invoke(
        'complete-registration', body: {'email': _c('email').text.trim(), 'password': _c('password').text, 'profile': profile, 'documents': documents},
      );
      if (response.data is Map && response.data['error'] != null) throw Exception(response.data['error']);
      if (!mounted) return;
      context.go(RouteNames.emailVerification, extra: {'email': _c('email').text.trim(), 'phone': _c('phone').text.trim()});
    } on Exception catch (error) {
      final dynamic e = error;
      _show(e.details?.toString() ?? e.reasonPhrase ?? e.message ?? error.toString());
    } catch (error) {
      _show(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _csv(String name) => _c(name).text.split(',').map((value) => value.trim()).where((value) => value.isNotEmpty).toList();
  Map<String, String> _statusDetails() => switch (_status) {
    'Student' => {'college': _c('college').text.trim(), 'course': _c('course').text.trim(), 'department': _c('department').text.trim(), 'semester': _c('semester').text.trim(), 'student_id': _c('studentId').text.trim(), 'graduation_year': _c('graduationYear').text.trim()},
    'Employed' => {'company': _c('company').text.trim(), 'job_title': _c('employmentTitle').text.trim(), 'start_date': _c('employmentStart').text.trim(), 'experience': _c('workExperience').text.trim()},
    'Unemployed' => {'previous_company': _c('previousCompany').text.trim(), 'previous_title': _c('previousTitle').text.trim(), 'experience': _c('workExperience').text.trim()},
    _ => {'details': _c('otherStatusDetails').text.trim()},
  };
  void _show(String message) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create your WorkSphere profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Complete registration', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8), const Text('Your profile is saved first. We then send an email verification link.'),
            const SizedBox(height: 24), _section('Basic details', [_field('Full name', 'fullName', validator: Validators.name), _field('Email address', 'email', type: TextInputType.emailAddress, validator: Validators.email), _field('Mobile number', 'phone', type: TextInputType.phone, validator: Validators.phone), _passwordField(), _field('Confirm password', 'confirmPassword', obscure: _obscurePassword, validator: Validators.password), _datePicker(), _field('Country', 'country'), _field('State', 'state'), _field('City', 'city'), _dropdown('Gender', _gender, const ['Prefer not to say', 'Female', 'Male', 'Non-binary'], (value) => setState(() => _gender = value!)), _documentTile('Profile photo', 'profile_photo', required: true)]),
            const SizedBox(height: 16), _section('Account type', [_roleSelector()]),
            const SizedBox(height: 16), _role == UserType.client ? _clientFields() : _freelancerFields(),
            const SizedBox(height: 24), WsButton(text: 'Create account and send verification email', onPressed: _submit, isLoading: _isLoading),
            const SizedBox(height: 12), TextButton(onPressed: () => context.go(RouteNames.login), child: const Text('Already have an account? Log in')),
          ],
        ),
      ),
    );
  }

  Widget _clientFields() => _section('Client and company details', [_field('Company name', 'companyName'), _field('Organization type', 'organizationType'), _field('Your job title / role', 'jobTitle'), _field('Industry', 'industry'), _field('Company website (optional)', 'website', validator: null), _field('Company description', 'companyDescription', lines: 3), _field('Freelancers / required skills (comma-separated)', 'requiredSkills'), _field('Project requirements', 'projectRequirements', lines: 3), _dropdown('Experience level required', _experienceLevel, const ['Entry level', 'Intermediate', 'Expert'], (value) => setState(() => _experienceLevel = value!)), _field('Budget range', 'budgetRange'), _documentTile('Company verification document', 'company_proof', required: true)]);

  Widget _freelancerFields() => _section('Freelancer profile', [_field('Professional headline', 'headline'), _field('About / bio', 'bio', lines: 4), _field('Primary skill', 'primarySkill'), _field('Secondary skills (comma-separated)', 'secondarySkills'), _field('Years of experience', 'yearsExperience', type: TextInputType.number), _field('Education', 'education'), _field('Certifications', 'certifications', validator: null), _field('Languages (comma-separated)', 'languages'), _field('Hourly rate (INR)', 'hourlyRate', type: TextInputType.number), _dropdown('Availability', _availability, const ['Available', 'Partially available', 'Unavailable'], (value) => setState(() => _availability = value!)), _field('Portfolio URL', 'portfolioUrl', validator: null), _field('Professional website (optional)', 'website', validator: null), _field('Other freelancing profiles (optional)', 'otherProfiles', validator: null), _dropdown('Current status', _status, const ['Student', 'Employed', 'Unemployed', 'Self-Employed', 'Other'], (value) => setState(() => _status = value!)), ..._statusFields()]);

  List<Widget> _statusFields() => switch (_status) {
    'Student' => [_field('College / university', 'college'), _field('Course / program', 'course'), _field('Department', 'department'), _field('Current year / semester', 'semester'), _field('Student ID / register number', 'studentId'), _field('Graduation year', 'graduationYear', type: TextInputType.number), _documentTile('College student ID card', 'student_id', required: true)],
    'Employed' => [_field('Current company name', 'company'), _field('Job title', 'employmentTitle'), _field('Employment start date', 'employmentStart'), _field('Work experience details', 'workExperience', lines: 3), _documentTile('Employment proof (optional)', 'employment_proof')],
    'Unemployed' => [_field('Previous company / organization', 'previousCompany'), _field('Previous job title', 'previousTitle'), _field('Previous work experience', 'workExperience', lines: 3), _documentTile('Supporting proof (optional)', 'supporting_proof')],
    _ => [_field('Describe your professional status', 'otherStatusDetails', lines: 3)],
  };

  Widget _section(String title, List<Widget> children) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 12), ...children])));
  Widget _field(String label, String name, {TextInputType? type, int lines = 1, bool obscure = false, String? Function(String?)? validator = Validators.required}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: WsTextField(label: label, hint: label, controller: _c(name), keyboardType: type ?? TextInputType.text, maxLines: lines, obscureText: obscure, validator: validator));
  Widget _passwordField() => Padding(padding: const EdgeInsets.only(bottom: 12), child: WsTextField(label: 'Password', hint: 'At least 8 characters', controller: _c('password'), obscureText: _obscurePassword, validator: Validators.password, suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscurePassword = !_obscurePassword))));
  Widget _dropdown(String label, String value, List<String> values, ValueChanged<String?> changed) => Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<String>(initialValue: value, decoration: InputDecoration(labelText: label), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: changed));
  Widget _datePicker() => ListTile(contentPadding: EdgeInsets.zero, title: const Text('Date of birth'), subtitle: Text(_dateOfBirth == null ? 'Required' : MaterialLocalizations.of(context).formatMediumDate(_dateOfBirth!)), trailing: const Icon(Icons.calendar_today_outlined), onTap: () async { final value = await showDatePicker(context: context, firstDate: DateTime(1900), lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)), initialDate: _dateOfBirth ?? DateTime(2000)); if (value != null) setState(() => _dateOfBirth = value); });
  Widget _roleSelector() => SegmentedButton<UserType>(segments: const [ButtonSegment(value: UserType.client, label: Text('Client'), icon: Icon(Icons.business_outlined)), ButtonSegment(value: UserType.freelancer, label: Text('Freelancer'), icon: Icon(Icons.work_outline))], selected: {_role}, onSelectionChanged: (selection) => setState(() => _role = selection.first));
  Widget _documentTile(String label, String type, {bool required = false}) {
    final file = _documents[type];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        file == null ? Icons.upload_file_outlined : Icons.check_circle,
        color: file == null ? null : Colors.green,
      ),
      title: Text('$label${required ? ' *' : ''}'),
      subtitle: Text(file?.name ?? 'JPEG, PNG, or PDF · maximum 5 MB'),
      trailing: file == null
          ? TextButton(
              onPressed: () => _pickDocument(type),
              child: const Text('Upload'),
            )
          : IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _documents.remove(type)),
            ),
    );
  }
}
