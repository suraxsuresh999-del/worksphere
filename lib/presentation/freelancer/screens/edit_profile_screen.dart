import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/widgets/ws_button.dart';
import '../../common/widgets/ws_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _country = TextEditingController();
  final _state = TextEditingController();
  final _city = TextEditingController();
  final _title = TextEditingController();
  final _bio = TextEditingController();
  final _primarySkill = TextEditingController();
  final _skills = TextEditingController();
  final _experience = TextEditingController();
  final _education = TextEditingController();
  final _certifications = TextEditingController();
  final _languages = TextEditingController();
  final _hourlyRate = TextEditingController();
  final _availability = TextEditingController();
  final _companyName = TextEditingController();
  final _companyDescription = TextEditingController();
  final _industry = TextEditingController();
  final _website = TextEditingController();
  final _companySize = TextEditingController();
  String _role = 'freelancer';
  String _preferredWorkType = 'remote';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final client = Supabase.instance.client;
      final profile = await client.from('profiles').select().eq('id', user.id).single();
      _role = profile['user_type'] as String? ?? 'freelancer';
      _fullName.text = profile['full_name'] as String? ?? '';
      _country.text = profile['country'] as String? ?? '';
      _state.text = profile['state'] as String? ?? '';
      _city.text = profile['city'] as String? ?? '';
      if (_role == 'client') {
        final details = await client.from('client_profiles').select().eq('user_id', user.id).maybeSingle();
        _companyName.text = details?['company_name'] as String? ?? '';
        _companyDescription.text = details?['description'] as String? ?? '';
        _industry.text = details?['industry'] as String? ?? '';
        _website.text = details?['website'] as String? ?? '';
        _companySize.text = details?['company_size'] as String? ?? '';
      } else {
        final details = await client.from('freelancer_profiles').select().eq('user_id', user.id).maybeSingle();
        _title.text = details?['title'] as String? ?? '';
        _bio.text = details?['bio'] as String? ?? '';
        _primarySkill.text = details?['primary_skill'] as String? ?? '';
        _skills.text = ((details?['secondary_skills'] as List?) ?? const []).join(', ');
        _experience.text = details?['years_experience']?.toString() ?? '';
        _education.text = details?['education_summary'] as String? ?? '';
        _certifications.text = details?['certifications'] as String? ?? '';
        _languages.text = ((details?['languages'] as List?) ?? const []).join(', ');
        _hourlyRate.text = details?['hourly_rate']?.toString() ?? '';
        _availability.text = details?['availability'] as String? ?? '';
        _preferredWorkType = details?['preferred_work_type'] as String? ?? 'remote';
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to load profile details.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _list(String value) => value.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.rpc('update_my_profile', params: {
        'full_name_input': _fullName.text.trim(),
        'country_input': _country.text.trim(),
        'state_input': _state.text.trim(),
        'city_input': _city.text.trim(),
        'title_input': _title.text.trim(),
        'bio_input': _bio.text.trim(),
        'primary_skill_input': _primarySkill.text.trim(),
        'secondary_skills_input': _list(_skills.text),
        'years_experience_input': double.tryParse(_experience.text.trim()),
        'education_input': _education.text.trim(),
        'certifications_input': _certifications.text.trim(),
        'languages_input': _list(_languages.text),
        'hourly_rate_input': double.tryParse(_hourlyRate.text.trim()),
        'availability_input': _availability.text.trim(),
        'preferred_work_type_input': _preferredWorkType,
        'company_name_input': _companyName.text.trim(),
        'company_description_input': _companyDescription.text.trim(),
        'industry_input': _industry.text.trim(),
        'website_input': _website.text.trim(),
        'company_size_input': _companySize.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved successfully.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save profile. Please try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [_fullName, _country, _state, _city, _title, _bio, _primarySkill, _skills, _experience, _education, _certifications, _languages, _hourlyRate, _availability, _companyName, _companyDescription, _industry, _website, _companySize]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(String label, TextEditingController controller, {int lines = 1, TextInputType? keyboardType}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: WsTextField(
      label: label,
      controller: controller,
      maxLines: lines,
      keyboardType: keyboardType ?? TextInputType.text,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isClient = _role == 'client';
    return Scaffold(
      appBar: AppBar(title: Text(isClient ? 'Edit Client Profile' : 'Edit Freelancer Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Basic information', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _field('Full name', _fullName),
            _field('Country', _country),
            _field('State', _state),
            _field('City', _city),
            Text(isClient ? 'Company details' : 'Professional details', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (isClient) ...[
              _field('Company name', _companyName),
              _field('About your company', _companyDescription, lines: 4),
              _field('Industry', _industry),
              _field('Website', _website, keyboardType: TextInputType.url),
              _field('Company size', _companySize),
            ] else ...[
              _field('Professional title', _title),
              _field('Bio / about', _bio, lines: 4),
              _field('Primary skill', _primarySkill),
              _field('Additional skills (comma separated)', _skills),
              _field('Years of experience', _experience, keyboardType: TextInputType.number),
              _field('Education', _education, lines: 2),
              _field('Certifications', _certifications, lines: 2),
              _field('Languages (comma separated)', _languages),
              _field('Hourly rate (Rs.)', _hourlyRate, keyboardType: TextInputType.number),
              _field('Availability', _availability),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: DropdownButtonFormField<String>(
                  initialValue: _preferredWorkType,
                  decoration: const InputDecoration(labelText: 'Preferred work type'),
                  items: const ['remote', 'onsite', 'hybrid'].map((item) => DropdownMenuItem(value: item, child: Text(item[0].toUpperCase() + item.substring(1)))).toList(),
                  onChanged: (value) => setState(() => _preferredWorkType = value ?? 'remote'),
                ),
              ),
            ],
            WsButton(text: 'Save changes', onPressed: _save, isLoading: _saving),
          ]),
        ),
      ),
    );
  }
}
